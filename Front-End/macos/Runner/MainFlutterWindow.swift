import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // MainMenu.xib ships Flutter's template default of 800×600, and the POS
    // treats anything under 1000pt wide as a compact 7"-class tablet (see
    // `isCompact` in lib/core/responsive.dart). An 800pt window therefore booted
    // a 13" Mac straight into the densest layout the app has. Match the Windows
    // runner instead, which opens at 1280×720 (windows/runner/main.cpp).
    //
    // Height is 800 rather than 720 because macOS spends vertical space on the
    // menu bar and the title bar that Windows does not.
    var size = NSSize(width: 1280, height: 800)
    if let visible = NSScreen.main?.visibleFrame.size {
      // Never open larger than the screen: on a small or scaled display an
      // oversized window opens partly off-screen with its controls unreachable.
      size.width = min(size.width, visible.width)
      size.height = min(size.height, visible.height)
    }
    self.setContentSize(size)

    // Below this the layout is legible but cramped; the operator can still make
    // the window smaller than the app was designed for, just not by accident
    // while dragging a corner.
    self.contentMinSize = NSSize(width: 1000, height: 700)

    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
