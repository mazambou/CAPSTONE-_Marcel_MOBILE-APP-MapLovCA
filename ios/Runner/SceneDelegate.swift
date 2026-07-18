import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var privacyView: UIView?

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    guard let windowScene = scene as? UIWindowScene,
          let window = windowScene.windows.first else { return }
    let cover = UIView(frame: window.bounds)
    cover.backgroundColor = .systemBackground
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    let icon = UIImageView(image: UIImage(systemName: "heart.shield.fill"))
    icon.tintColor = UIColor(red: 1, green: 0.35, blue: 0.37, alpha: 1)
    icon.contentMode = .scaleAspectFit
    icon.frame = CGRect(x: 0, y: 0, width: 82, height: 82)
    icon.center = cover.center
    cover.addSubview(icon)
    window.addSubview(cover)
    privacyView = cover
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    privacyView?.removeFromSuperview()
    privacyView = nil
  }
}
