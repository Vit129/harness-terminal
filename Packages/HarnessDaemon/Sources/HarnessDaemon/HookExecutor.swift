import Foundation
import HarnessCore

/// Fires hooks asynchronously after the registry lock is released.
/// Extracted from SurfaceRegistry for single-responsibility.
final class HookExecutor: Sendable {
    private let hookRegistry: HookRegistry
    private let hookQueue: DispatchQueue

    init(hookRegistry: HookRegistry, hookQueue: DispatchQueue) {
        self.hookRegistry = hookRegistry
        self.hookQueue = hookQueue
    }

    func fire(_ event: HookEvent, context: FormatContext) {
        hookQueue.async { [weak self] in self?.hookRegistry.fire(event, context: context) }
    }
}
