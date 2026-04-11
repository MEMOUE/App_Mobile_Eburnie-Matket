import Flutter
import UIKit
import GoogleSignIn

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Configuration obligatoire pour GoogleSignIn SDK 8.x
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(
      clientID: "335632105023-o9bd3gekvjk2qcqkrd62vlimqoartoc8.apps.googleusercontent.com"
    )
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}