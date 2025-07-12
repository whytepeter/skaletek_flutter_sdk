import Flutter
import UIKit
import Amplify
import AWSCognitoAuthPlugin

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Amplify for native iOS plugins
    do {
      try Amplify.add(plugin: AWSCognitoAuthPlugin())
      try Amplify.configure()
      print("✅ Amplify configured with Auth plugin")
    } catch {
      print("⚠️ Could not initialize Amplify: \(error)")
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
