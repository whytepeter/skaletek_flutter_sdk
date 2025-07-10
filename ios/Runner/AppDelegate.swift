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
    // 1) Configure Amplify
    do {
      try Amplify.add(plugin: AWSCognitoAuthPlugin())
      try Amplify.configure()
      print("✅ Amplify configured with Auth plugin")
    } catch {
      print("⚠️ Could not initialize Amplify: \(error)")
    }

    // 2) Register Flutter plugins as usual
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

