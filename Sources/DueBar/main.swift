import AppKit

// macOS only grants a WindowServer GUI session to processes launched via Launch
// Services from a .app bundle. A bare binary run from the terminal (e.g. swift run)
// never receives that session, so NSStatusBar items are created but never displayed.
guard Bundle.main.bundlePath.hasSuffix(".app") else {
    fputs("""
    DueBar requires a .app bundle — macOS will not show menu bar items for a
    bare binary launched from the terminal.

    Build and open the bundle:
      Scripts/package_app.sh && open build/DueBar.app

    """, stderr)
    exit(1)
}

// One-shot login-item toggles — register/unregister and exit before the GUI
// starts, so "launch at login" can be flipped from the command line too.
if CommandLine.arguments.contains("--register-login")   { LoginItem.runCLI(enable: true) }
if CommandLine.arguments.contains("--unregister-login") { LoginItem.runCLI(enable: false) }

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
