import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {

    }
    
    // 액티브 상태가 되었을 경우
    func sceneDidBecomeActive(_ scene: UIScene) {
        callBackgroundImage(false)
    }

    // 홈 바를 쓸어 올리거나 홈버튼을 두번 눌렀을 경우
    func sceneWillResignActive(_ scene: UIScene) {
    }

    // 백그라운드 상태였다가 돌아왔을 때
    func sceneWillEnterForeground(_ scene: UIScene) {
        callBackgroundImage(false)
    }

    // 백그라운드 상태로 갔을 때
    func sceneDidEnterBackground(_ scene: UIScene) {
        callBackgroundImage(true)
    }

    func callBackgroundImage(_ bShow: Bool) {
            
            let TAG_BG_IMG = -101
            let backgroundView = window?.viewWithTag(TAG_BG_IMG)

            if bShow {

                if backgroundView == nil {

                    //여기서 보여주고 싶은 뷰 자유롭게 생성
                    let bgView = UIView()
                    bgView.frame = UIScreen.main.bounds
                    bgView.tag = TAG_BG_IMG
                    bgView.backgroundColor = .secondarySystemBackground
                    
                    let appIcon = UIImageView()
                    appIcon.frame = CGRect(x: bgView.layer.bounds.width / 2 - 64, y: bgView.layer.bounds.height / 2 - 64, width: 128, height: 128)
                    appIcon.image = UIImage(named: "bgView")
                    bgView.addSubview(appIcon)
                    
                    window?.addSubview(bgView)
                }
            } else {

                if let backgroundView = backgroundView {
                    backgroundView.removeFromSuperview()
                }
            }
        }
}

