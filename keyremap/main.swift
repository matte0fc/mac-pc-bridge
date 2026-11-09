// keyremap
// Makes a Windows keyboard (shared to the Mac through Deskflow) feel at home on macOS:
//
//  • Left Alt + Space  ->  Cmd + Space (Spotlight / launcher), but ONLY for key presses
//    that come from Deskflow. The Mac's built-in keyboard is left untouched.
//  • Ctrl + A / C / V  ->  Cmd + A / C / V (select all, copy, paste) from any keyboard,
//    except in terminal apps, where Ctrl keys mean something else.
//
// Run with --debug to log every Space and Ctrl+A/C/V press.

import Cocoa
import ApplicationServices
import Darwin

let debug = CommandLine.arguments.contains("--debug")
let spaceKey: Int64 = 49
// Physical key codes: A=0, C=8, V=9
let ctrlKeys: [Int64: String] = [0: "a", 8: "c", 9: "v"]

// Apps where Ctrl+A/C/V should stay Ctrl
let ctrlExcluded: Set<String> = [
    "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty",
    "com.github.wez.wezterm", "net.kovidgoyal.kitty", "io.alacritty",
    "dev.warp.Warp-Stable", "co.zeit.hyper"
]

// Device-specific (left/right) bits in the event flags
let leftAlt:   UInt64 = 0x20
let rightAlt:  UInt64 = 0x40
let leftCmd:   UInt64 = 0x08
let leftCtrl:  UInt64 = 0x01
let rightCtrl: UInt64 = 0x2000

func log(_ s: String) {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    print("\(f.string(from: Date())) \(s)"); fflush(stdout)
}

func frontmostBundleID() -> String {
    NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
}

// Ctrl+A/C/V -> Cmd+A/C/V
func remapCtrl(_ event: CGEvent, _ type: CGEventType, _ key: String) {
    let flags = event.flags
    guard flags.contains(.maskControl),
          !flags.contains(.maskCommand),
          !flags.contains(.maskAlternate),
          !flags.contains(.maskShift) else { return }
    let app = frontmostBundleID()
    if ctrlExcluded.contains(app) {
        if debug { log("ctrl+\(key) in \(app): left as is") }
        return
    }
    var newRaw = flags.rawValue & ~(CGEventFlags.maskControl.rawValue | leftCtrl | rightCtrl)
    newRaw |= CGEventFlags.maskCommand.rawValue | leftCmd
    event.flags = CGEventFlags(rawValue: newRaw)
    if debug { log("ctrl+\(key) \(type == .keyDown ? "down" : "up") in \(app) -> Cmd+\(key.uppercased())") }
}

// Is this process Deskflow? Cached per pid, since every key press asks.
var pidCache: [pid_t: Bool] = [:]
func isDeskflow(_ pid: pid_t) -> Bool {
    if pid <= 0 { return false }
    if let hit = pidCache[pid] { return hit }
    var buf = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
    let n = proc_pidpath(pid, &buf, UInt32(buf.count))
    let path = n > 0 ? String(cString: buf) : ""
    let ok = path.lowercased().contains("deskflow")
    pidCache[pid] = ok
    return ok
}

var tap: CFMachPort?

let callback: CGEventTapCallBack = { _, type, event, _ in
    // macOS switches the tap off if it is ever too slow: switch it back on
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
        log("tap was disabled, re-enabled it")
        return Unmanaged.passUnretained(event)
    }
    guard type == .keyDown || type == .keyUp else {
        return Unmanaged.passUnretained(event)
    }
    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    if let key = ctrlKeys[keycode] {
        remapCtrl(event, type, key)
        return Unmanaged.passUnretained(event)
    }
    guard keycode == spaceKey else {
        return Unmanaged.passUnretained(event)
    }

    let pid = pid_t(event.getIntegerValueField(.eventSourceUnixProcessID))
    let flags = event.flags
    let raw = flags.rawValue
    let fromDeskflow = isDeskflow(pid)

    if debug {
        log("space \(type == .keyDown ? "down" : "up") pid=\(pid) deskflow=\(fromDeskflow) flags=0x\(String(raw, radix: 16))")
    }

    guard fromDeskflow,
          flags.contains(.maskAlternate),
          !flags.contains(.maskCommand),
          !flags.contains(.maskControl),
          !flags.contains(.maskShift) else {
        return Unmanaged.passUnretained(event)
    }
    // Left Alt only: skip when it is clearly right Alt (AltGr)
    if raw & rightAlt != 0 && raw & leftAlt == 0 {
        return Unmanaged.passUnretained(event)
    }

    var newRaw = raw & ~(CGEventFlags.maskAlternate.rawValue | leftAlt | rightAlt)
    newRaw |= CGEventFlags.maskCommand.rawValue | leftCmd
    event.flags = CGEventFlags(rawValue: newRaw)
    if debug { log("  -> Cmd+Space") }
    return Unmanaged.passUnretained(event)
}

// Ask for Accessibility permission (macOS shows its dialog the first time)
let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(opts) {
    log("Waiting for Accessibility permission (System Settings → Privacy & Security → Accessibility)…")
    while !AXIsProcessTrusted() { sleep(2) }
    log("Permission granted")
}

let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                place: .headInsertEventTap,
                                options: .defaultTap,
                                eventsOfInterest: mask,
                                callback: callback,
                                userInfo: nil) else {
    log("Could not create the event tap. Is Accessibility permission missing?")
    exit(1)
}
tap = t
let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
CGEvent.tapEnable(tap: t, enable: true)
log("keyremap running\(debug ? " (debug)" : "")")
CFRunLoopRun()
