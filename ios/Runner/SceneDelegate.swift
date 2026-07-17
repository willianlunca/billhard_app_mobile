@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)

        let controller = FlutterViewController.init(engine: flutterEngine, nibName: nil, bundle: nil)
        controller.loadDefaultSplashScreenView()
        window?.rootViewController = controller
        window?.makeKeyAndVisible()
    }
}

//
//  SceneDelegate.swift
//  Runner
//
//  Created by Willian Lunca on 12/07/26.
//

