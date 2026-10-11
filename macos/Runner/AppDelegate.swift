import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Carries books sent by "Open with" to the Dart side.
  private var openWith: FlutterMethodChannel?

  /// The file the app was launched to open, until Dart asks for it.
  private var launchFile: String?
  private var asked = false

  func listenForOpenWith(on messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.varagh/open_with", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "initialFile" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.launchFile)
      self?.launchFile = nil
      self?.asked = true
    }
    openWith = channel
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    guard let path = urls.first(where: { $0.isFileURL })?.path else { return }
    if asked {
      openWith?.invokeMethod("openFile", arguments: path)
    } else {
      launchFile = path
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
