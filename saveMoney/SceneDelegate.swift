import UIKit
import SwiftUI
import SwiftData
import UserNotifications

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // 스토리보드(mainVC) 대신 SwiftUI MainView를 루트로 사용
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: MainView()
            .modelContainer(PersistenceController.shared)
        )
        self.window = window
        window.makeKeyAndVisible()

        #if DEBUG
        applyLaunchOverridesForUITest(window)
        #endif
    }

    #if DEBUG
    // 디자인 검증용 (시뮬레이터 스크린샷 자동화):
    // SIMCTL_CHILD_SEED_DEMO_DATA=1 → 데모 데이터 주입
    // SIMCTL_CHILD_SHOW_SCREEN=calendar|fixed|revenue → 해당 화면을 루트로
    private func applyLaunchOverridesForUITest(_ window: UIWindow) {
        let env = ProcessInfo.processInfo.environment

        if env["SEED_DEMO_DATA"] == "1" {
            seedDemoData()
        }

        switch env["SHOW_SCREEN"] {
        case "calendar":
            window.rootViewController = UIHostingController(rootView:
                CalendarView(start: Date().startOfThisMonth, end: Date().endOfThisMonth)
                    .modelContainer(PersistenceController.shared)
            )
        case "fixed":
            window.rootViewController = UIHostingController(rootView:
                FixedExpenditureView()
                    .modelContainer(PersistenceController.shared)
            )
        case "revenue":
            window.rootViewController = UIHostingController(rootView:
                RevenueView(start: Date().startOfThisMonth, end: Date().endOfThisMonth)
                    .modelContainer(PersistenceController.shared)
            )
        default:
            break
        }
    }

    private func seedDemoData() {
        // Preview와 동일한 데모 데이터를 실제 컨테이너에 주입
        PreviewSampleData.seed(into: ModelContext(PersistenceController.shared))
    }
    #endif
    
    func sceneDidDisconnect(_ scene: UIScene) {
        
    }
    
    // 액티브 상태가 되었을 경우
    func sceneDidBecomeActive(_ scene: UIScene) {
        callBackgroundImage(false)
        // iOS 17+: applicationIconBadgeNumber(get/set) deprecated → UNUserNotificationCenter 사용
        UNUserNotificationCenter.current().setBadgeCount(0)
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

