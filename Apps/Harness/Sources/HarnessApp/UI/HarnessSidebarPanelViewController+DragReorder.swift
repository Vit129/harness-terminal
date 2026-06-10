import AppKit
import HarnessCore

extension HarnessSidebarPanelViewController {
    // MARK: - Drag to reorder

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        // Reorder maps to the unfiltered list, so it's only meaningful with no
        // active filter (displayed rows == sessions then).
        guard sessionFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let session = sessionRow(at: row) else { return nil }
        let item = NSPasteboardItem()
        item.setString(session.id.uuidString, forType: Self.sessionRowPasteboardType)
        return item
    }

    func tableView(
        _ tableView: NSTableView,
        validateDrop info: NSDraggingInfo,
        proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        guard dropOperation == .above else { return [] }
        guard sessionFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        guard canDropSession(info, aboveRow: row) else { return [] }
        return .move
    }

    func tableView(
        _ tableView: NSTableView,
        acceptDrop info: NSDraggingInfo,
        row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        guard let workspaceID = activeWorkspaceID,
              let item = info.draggingPasteboard.pasteboardItems?.first,
              let raw = item.string(forType: Self.sessionRowPasteboardType),
              let sessionID = UUID(uuidString: raw),
              let from = sessionIndex(for: sessionID),
              let target = targetSessionIndex(forDropAboveRow: row, movingSessionID: sessionID)
        else { return false }
        guard target != from else { return false }
        SessionCoordinator.shared.reorderSession(
            workspaceID: workspaceID,
            sessionID: sessionID,
            toIndex: target
        )
        return true
    }

    private func canDropSession(_ info: NSDraggingInfo, aboveRow row: Int) -> Bool {
        guard let item = info.draggingPasteboard.pasteboardItems?.first,
              let raw = item.string(forType: Self.sessionRowPasteboardType),
              let sessionID = UUID(uuidString: raw)
        else { return false }
        return targetSessionIndex(forDropAboveRow: row, movingSessionID: sessionID) != nil
    }

    private func targetSessionIndex(forDropAboveRow row: Int, movingSessionID: SessionID) -> Int? {
        guard let sourceGroup = sessionGroupName(for: movingSessionID),
              let sourceIndex = sessionIndex(for: movingSessionID)
        else { return nil }

        let rows = cachedSidebarRows
        guard !rows.isEmpty else { return nil }
        let clampedRow = max(0, min(row, rows.count))

        let targetSession: SessionGroup?
        let placeAfterTarget: Bool
        if clampedRow < rows.count {
            switch rows[clampedRow] {
            case let .session(session):
                targetSession = session
                placeAfterTarget = false
            case .groupHeader:
                targetSession = previousSession(beforeRow: clampedRow, in: rows)
                placeAfterTarget = true
            }
        } else {
            targetSession = rows.reversed().compactMap {
                if case let .session(session) = $0 { return session }
                return nil
            }.first
            placeAfterTarget = true
        }

        guard let targetSession,
              projectGroupName(for: targetSession) == sourceGroup,
              let rawTargetIndex = sessionIndex(for: targetSession.id)
        else { return nil }

        let rawDropIndex = placeAfterTarget ? rawTargetIndex + 1 : rawTargetIndex
        let targetIndex = sourceIndex < rawDropIndex ? rawDropIndex - 1 : rawDropIndex
        return max(0, min(targetIndex, sessions.count - 1))
    }

    private func previousSession(beforeRow row: Int, in rows: [SidebarSessionRow]) -> SessionGroup? {
        guard row > 0 else { return nil }
        for index in stride(from: row - 1, through: 0, by: -1) {
            if case let .session(session) = rows[index] { return session }
            if case .groupHeader = rows[index] { return nil }
        }
        return nil
    }
}
