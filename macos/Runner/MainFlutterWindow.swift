import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Register app-level plugins that are not auto-generated.
    let registrar = flutterViewController.registrar(forPlugin: "VisionOcrPlugin")
    VisionOcrPlugin.register(with: registrar)

    super.awakeFromNib()
  }
}
