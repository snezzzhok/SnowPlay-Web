import Foundation
public enum WindowPhase: String { case created, visible, active, inactive, moving, resizing, minimizing, minimized, restoring, closing, closed }
public enum WindowEvent { case show, activate, deactivate, move, resize, minimize, minimized, restore, settle, close, closed }
public struct WindowState {
    public private(set) var phase = WindowPhase.created
    public private(set) var inactiveSince: Double?
    public private(set) var frost = 0.0
    public private(set) var restoreProgress = 1.0
    public private(set) var stableAt = 0.0
    public init(now: Double = 0) { stableAt=now+0.2 }
    public mutating func send(_ event: WindowEvent, now: Double) {
        guard phase != .closed else { return }
        if phase == .closing { if case .closed=event { phase = .closed }; return }
        switch event {
        case .show: phase = .visible; stableAt=now+0.2; inactiveSince=now
        case .activate: phase = .active; inactiveSince=nil
        case .deactivate: phase = .inactive; if inactiveSince == nil { inactiveSince=now }
        case .move: phase = .moving; stableAt=now+0.2
        case .resize: phase = .resizing; stableAt=now+0.2
        case .minimize: phase = .minimizing
        case .minimized: phase = .minimized
        case .restore: phase = .restoring; restoreProgress=0; stableAt=now+0.2
        case .settle: phase = inactiveSince == nil ? .active : .inactive
        case .close: phase = .closing
        case .closed: phase = .closed
        }
    }
    public mutating func tick(dt: Double, now: Double) {
        let target=inactiveSince.map { clamp((now-$0-20)/40,0,1) } ?? 0
        if target < frost { frost=max(target,frost-dt*2) } else { frost=target }
        // Activation and geometry events may arrive while the saved layer is settling.
        // The restoration clock must survive those phase changes.
        if restoreProgress<1 && canAccumulate {
            restoreProgress=min(1,restoreProgress+dt/0.4)
            if restoreProgress>=1 && phase == .restoring { phase = .visible }
        }
        if (phase == .moving || phase == .resizing) && now >= stableAt { phase = inactiveSince == nil ? .active : .inactive }
    }
    public var canAccumulate: Bool { ![.created,.minimized,.minimizing,.closing,.closed].contains(phase) }
}
