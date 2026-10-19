import UIKit
import SwiftUI
import SwiftData
import UserNotifications

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private weak var privacyOverlayView: UIView?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // 스토리보드(mainVC) 대신 SwiftUI MainView를 루트로 사용
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = makeAppHostingController(rootView: MainView())
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

        if env[LaunchEnvKeys.seedDemoData] == "1" {
            seedDemoData()
        }

        switch env[LaunchEnvKeys.showScreen] {
        case "calendar":
            window.rootViewController = makeAppHostingController(
                rootView: CalendarView(start: Date().startOfThisMonth, end: Date().endOfThisMonth)
            )
        case "fixed":
            window.rootViewController = makeAppHostingController(
                rootView: FixedExpenditureView()
            )
        case "revenue":
            window.rootViewController = makeAppHostingController(
                rootView: RevenueView(start: Date().startOfThisMonth, end: Date().endOfThisMonth)
            )
        default:
            break
        }
    }

    private func seedDemoData() {
        // Preview와 동일한 데모 데이터를 실제 컨테이너에 주입.
        // seed()는 기존 수입·지출·고정지출을 전부 지우므로 시뮬레이터에서만 허용한다
        // (PreviewSampleData 쪽에도 같은 가드가 있음 — 실기기 데이터 보호용 이중 방어)
        #if targetEnvironment(simulator)
        PreviewSampleData.seed(into: ModelContext(PersistenceController.shared))
        #endif
    }
    #endif

    // 액티브 상태가 되었을 경우
    func sceneDidBecomeActive(_ scene: UIScene) {
        setPrivacyOverlayVisible(false)
        // iOS 17+: applicationIconBadgeNumber(get/set) deprecated → UNUserNotificationCenter 사용
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    // 백그라운드 상태였다가 돌아왔을 때
    func sceneWillEnterForeground(_ scene: UIScene) {
        setPrivacyOverlayVisible(false)
    }

    // 백그라운드 상태로 갔을 때
    func sceneDidEnterBackground(_ scene: UIScene) {
        setPrivacyOverlayVisible(true)
    }

    private func setPrivacyOverlayVisible(_ show: Bool) {
        guard show else {
            privacyOverlayView?.removeFromSuperview()
            privacyOverlayView = nil
            return
        }
        guard privacyOverlayView == nil, let window else { return }

        let bgView = UIView(frame: window.bounds)
        bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bgView.backgroundColor = .secondarySystemBackground

        let appIcon = UIImageView(image: UIImage(named: "bgView"))
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(appIcon)

        NSLayoutConstraint.activate([
            appIcon.centerXAnchor.constraint(equalTo: bgView.centerXAnchor),
            appIcon.centerYAnchor.constraint(equalTo: bgView.centerYAnchor),
            appIcon.widthAnchor.constraint(equalToConstant: 128),
            appIcon.heightAnchor.constraint(equalToConstant: 128)
        ])

        window.addSubview(bgView)
        privacyOverlayView = bgView
    }
}

