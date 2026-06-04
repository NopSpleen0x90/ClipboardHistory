import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // nessuna icona nel Dock

let delegate = AppDelegate()
app.delegate = delegate

app.run()
