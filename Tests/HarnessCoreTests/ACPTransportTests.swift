import XCTest
@testable import HarnessCore

final class ACPTransportTests: XCTestCase {
    func testRequestRoundTrip() throws {
        let message = ACPMessage.request(
            id: .int(1),
            method: "session/new",
            params: .object(["cwd": .string("/tmp/project"), "interactive": .bool(true)])
        )
        XCTAssertEqual(try ACPTransport.decode(from: ACPTransport.encode(message)), message)
    }

    func testResponseRoundTrip() throws {
        let message = ACPMessage.response(
            id: .string("request-1"),
            result: .object(["ok": .bool(true), "count": .int(3)]),
            error: nil
        )
        XCTAssertEqual(try ACPTransport.decode(from: ACPTransport.encode(message)), message)
    }

    func testNotificationRoundTrip() throws {
        let message = ACPMessage.notification(
            method: "session/progress",
            params: .array([.string("started"), .double(0.5), .null])
        )
        XCTAssertEqual(try ACPTransport.decode(from: ACPTransport.encode(message)), message)
    }

    func testContentLengthHeaderAllowsWhitespace() throws {
        let body = try JSONEncoder().encode(ACPMessage.notification(method: "ping", params: nil))
        var frame = Data("Content-Length:   \(body.count) \r\n\r\n".utf8)
        frame.append(body)

        XCTAssertEqual(
            try ACPTransport.decode(from: frame),
            ACPMessage.notification(method: "ping", params: nil)
        )
    }

    func testPartialDataBufferReturnsNilUntilComplete() throws {
        let message = ACPMessage.request(id: .int(7), method: "agent/call", params: .object(["value": .int(42)]))
        let frame = try ACPTransport.encode(message)
        let splitIndex = frame.index(frame.startIndex, offsetBy: frame.count / 2)
        let buffer = TransportBuffer()

        buffer.append(frame[..<splitIndex])
        XCTAssertNil(try buffer.nextMessage())

        buffer.append(frame[splitIndex...])
        XCTAssertEqual(try buffer.nextMessage(), message)
        XCTAssertNil(try buffer.nextMessage())
    }
}
