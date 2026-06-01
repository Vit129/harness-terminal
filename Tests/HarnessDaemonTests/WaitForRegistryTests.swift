import XCTest
@testable import HarnessDaemonCore

/// `wait-for` channel semantics — pure, fd-based (no sockets), so fully unit-testable.
final class WaitForRegistryTests: XCTestCase {
    func testSignalWakesAllWaiters() {
        let r = WaitForRegistry()
        r.wait(channel: "ch", fd: 3)
        r.wait(channel: "ch", fd: 4)
        XCTAssertEqual(Set(r.signal(channel: "ch")), [3, 4], "signal wakes every waiter")
        XCTAssertEqual(r.signal(channel: "ch"), [], "a second signal has no waiters (not latched)")
    }

    func testSignalUnknownChannelIsNoOp() {
        let r = WaitForRegistry()
        XCTAssertEqual(r.signal(channel: "nope"), [])
    }

    func testLockMutexSemantics() {
        let r = WaitForRegistry()
        XCTAssertTrue(r.lock(channel: "m", fd: 1), "first lock acquires immediately")
        XCTAssertFalse(r.lock(channel: "m", fd: 2), "second lock defers while held")
        XCTAssertEqual(r.unlock(channel: "m"), 2, "unlock hands the lock to the queued waiter")
        XCTAssertNil(r.unlock(channel: "m"), "unlock with no waiters releases and returns nil")
        XCTAssertTrue(r.lock(channel: "m", fd: 5), "lock acquires again after full release")
    }

    func testRemoveDropsWaiterAndLockWaiter() {
        let r = WaitForRegistry()
        r.wait(channel: "ch", fd: 7)
        _ = r.remove(fd: 7)
        XCTAssertEqual(r.signal(channel: "ch"), [], "a removed (disconnected) fd is not woken")

        XCTAssertTrue(r.lock(channel: "m", fd: 1))
        XCTAssertFalse(r.lock(channel: "m", fd: 2))
        XCTAssertEqual(r.remove(fd: 2), [], "removing a queued lock-waiter grants no one")
        XCTAssertNil(r.unlock(channel: "m"), "a removed lock-waiter isn't granted the lock")
    }

    func testRemoveReleasesHeldLockToNextWaiter() {
        let r = WaitForRegistry()
        XCTAssertTrue(r.lock(channel: "m", fd: 1), "holder acquires")
        XCTAssertFalse(r.lock(channel: "m", fd: 2), "second locker queues")
        XCTAssertFalse(r.lock(channel: "m", fd: 3), "third locker queues")
        // The holder disconnects without unlocking — the lock must pass to the next queued locker
        // (fd 2), whose deferred reply the caller now sends. A wedged channel here would park
        // every later locker forever (the bug this guards).
        XCTAssertEqual(r.remove(fd: 1), [2], "holder disconnect hands the lock to the next waiter")
        XCTAssertFalse(r.lock(channel: "m", fd: 4), "channel is still held by fd 2")
        XCTAssertEqual(r.unlock(channel: "m"), 3, "a normal unlock then drains the queue (fd 3)")
    }

    func testRemoveHeldLockWithNoWaitersFreesChannel() {
        let r = WaitForRegistry()
        XCTAssertTrue(r.lock(channel: "m", fd: 1))
        XCTAssertEqual(r.remove(fd: 1), [], "sole holder disconnect frees the channel, grants no one")
        XCTAssertTrue(r.lock(channel: "m", fd: 2), "channel is free again after the holder vanished")
    }

    func testEmptiedChannelsArePrunedSoTheMapDoesNotGrowUnbounded() {
        let r = WaitForRegistry()
        // A script that signals/unlocks many unique channel names must not leak an entry per name.
        for i in 0 ..< 100 {
            let ch = "ch-\(i)"
            r.wait(channel: ch, fd: Int32(i))
            _ = r.signal(channel: ch)            // wakes + empties the channel
        }
        XCTAssertEqual(r.activeChannelCount, 0, "signalled-empty channels are pruned")

        XCTAssertTrue(r.lock(channel: "m", fd: 1))
        XCTAssertEqual(r.activeChannelCount, 1)
        XCTAssertNil(r.unlock(channel: "m"))      // releases with no waiters → empty → pruned
        XCTAssertEqual(r.activeChannelCount, 0, "fully-unlocked channels are pruned")
    }

    func testRemovePrunesChannelsLeftEmptyByDisconnect() {
        let r = WaitForRegistry()
        r.wait(channel: "a", fd: 7)
        r.wait(channel: "b", fd: 7)
        XCTAssertEqual(r.activeChannelCount, 2)
        _ = r.remove(fd: 7)                       // the only waiter on both → both go empty
        XCTAssertEqual(r.activeChannelCount, 0, "channels emptied by a disconnect are pruned")
    }
}
