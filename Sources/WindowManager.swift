import Cocoa
import ApplicationServices

final class WindowManager {
    private var permissionTimer: Timer?
    private var eventTap: CFMachPort?
    private var tapSource: CFRunLoopSource?

    private let minWidth:  CGFloat = 400
    private let minHeight: CGFloat = 250

    // MARK: - Entry

    func start() {
        if AXIsProcessTrusted() {
            beginManaging()
        } else {
            promptPermission()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard AXIsProcessTrusted() else { return }
                self?.permissionTimer?.invalidate()
                self?.permissionTimer = nil
                DispatchQueue.main.async { self?.beginManaging() }
            }
        }
    }

    private func promptPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    private func beginManaging() {
        maximizeAll()
        setupEventTap()
    }

    // MARK: - Maximize

    func maximizeAll() {
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            maximizeWindows(of: app)
        }
    }

    private func maximizeWindows(of app: NSRunningApplication) {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var val: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &val) == .success,
              let windows = val as? [AXUIElement] else { return }
        windows.forEach { maximizeIfEligible($0) }
    }

    private func maximizeIfEligible(_ win: AXUIElement) {
        if axBool(win, kAXMinimizedAttribute as CFString) == true { return }
        if axBool(win, "AXFullScreen" as CFString) == true { return }
        guard axString(win, kAXRoleAttribute as CFString) == (kAXWindowRole as String) else { return }
        guard let frame = axFrame(win),
              frame.width >= minWidth, frame.height >= minHeight else { return }
        let screen = bestScreen(for: frame)
        guard !isMaximized(frame, on: screen) else { return }
        maximize(win, on: screen)
    }

    private func maximize(_ win: AXUIElement, on screen: NSScreen) {
        guard let primary = NSScreen.screens.first else { return }
        let vf = screen.visibleFrame
        setAXFrame(win, rect: CGRect(
            x: vf.minX,
            y: primary.frame.height - vf.maxY,
            width: vf.width,
            height: vf.height
        ))
    }

    private func isMaximized(_ frame: CGRect, on screen: NSScreen) -> Bool {
        guard let primary = NSScreen.screens.first else { return false }
        let vf = screen.visibleFrame
        let t = CGRect(x: vf.minX, y: primary.frame.height - vf.maxY, width: vf.width, height: vf.height)
        let ε: CGFloat = 4
        return abs(frame.minX - t.minX) < ε && abs(frame.minY - t.minY) < ε &&
               abs(frame.width - t.width) < ε && abs(frame.height - t.height) < ε
    }

    // MARK: - Event Tap (green zoom button → maximize instead of fullscreen)

    private func setupEventTap() {
        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, ref -> Unmanaged<CGEvent>? in
                guard let ref else { return Unmanaged.passRetained(event) }
                return Unmanaged<WindowManager>.fromOpaque(ref).takeUnretainedValue().handleClick(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap = eventTap else { return }
        tapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), tapSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleClick(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let loc = event.location
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return Unmanaged.passRetained(event) }

        for info in list {
            guard (info[kCGWindowLayer as String] as? Int32) == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let bd  = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }

            let wf = CGRect(x: bd["X"] ?? 0, y: bd["Y"] ?? 0,
                            width: bd["Width"] ?? 0, height: bd["Height"] ?? 0)
            guard hypot(loc.x - (wf.minX + 53), loc.y - (wf.minY + 13)) < 16 else { continue }

            let axApp = AXUIElementCreateApplication(pid)
            var ref: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &ref) == .success,
                  let wins = ref as? [AXUIElement] else { continue }

            for win in wins {
                guard let frame = axFrame(win),
                      abs(frame.minX - wf.minX) < 8, abs(frame.minY - wf.minY) < 8 else { continue }
                let screen = bestScreen(for: frame)
                if isMaximized(frame, on: screen) {
                    return Unmanaged.passRetained(event)
                }
                maximize(win, on: screen)
                return nil
            }
        }
        return Unmanaged.passRetained(event)
    }

    // MARK: - AX Helpers

    private func axFrame(_ win: AXUIElement) -> CGRect? {
        var pv: CFTypeRef?, sv: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &pv) == .success,
              AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sv) == .success,
              let pv, let sv else { return nil }
        var pos = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(pv as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sv as! AXValue, .cgSize, &size)
        return CGRect(origin: pos, size: size)
    }

    private func setAXFrame(_ win: AXUIElement, rect: CGRect) {
        var o = rect.origin, s = rect.size
        if let pv = AXValueCreate(.cgPoint, &o) { AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, pv) }
        if let sv = AXValueCreate(.cgSize, &s)  { AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, sv) }
    }

    private func axBool(_ el: AXUIElement, _ attr: CFString) -> Bool? {
        var val: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr, &val) == .success else { return nil }
        return val as? Bool
    }

    private func axString(_ el: AXUIElement, _ attr: CFString) -> String? {
        var val: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr, &val) == .success else { return nil }
        return val as? String
    }

    private func bestScreen(for cg: CGRect) -> NSScreen {
        guard let primary = NSScreen.screens.first else { return NSScreen.main! }
        let ns = CGRect(x: cg.minX, y: primary.frame.height - cg.maxY, width: cg.width, height: cg.height)
        return NSScreen.screens.max { $0.frame.intersection(ns).area < $1.frame.intersection(ns).area } ?? NSScreen.main!
    }
}

private extension CGRect { var area: CGFloat { width * height } }
