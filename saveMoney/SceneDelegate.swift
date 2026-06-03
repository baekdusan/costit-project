import UIKit
import SwiftUI
import SwiftData

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
    // SIMCTL_CHILD_SHOW_SCREEN=calendar|fixed → 해당 화면을 루트로
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
        default:
            break
        }
    }

    private func seedDemoData() {
        let context = ModelContext(PersistenceController.shared)

        // 기존 데이터 정리
        try? context.delete(model: FinDataEntity.self)
        try? context.delete(model: FixedExpenditureEntity.self)

        let cal = Calendar.current
        func day(_ d: Int) -> Date {
            cal.date(byAdding: .day, value: d - 1, to: Date().startOfThisMonth) ?? Date()
        }

        let expenses: [(Int, String, Int)] = [
            (2, "빠레뜨 한남 (부평, 민주)", 36000),
            (2, "GS25 음료수", 3200),
            (5, "넷플릭스", 14500),
            (5, "점심 김치찌개", 9000),
            (8, "스타벅스", 6300),
            (12, "교보문고", 28800),
            (12, "지하철 충전", 20000),
            (15, "올리브영", 17900),
        ]
        for (d, what, how) in expenses {
            context.insert(FinDataEntity(when: day(d), towhat: what, how: how, isRevenue: false))
        }

        context.insert(FinDataEntity(when: day(1), towhat: "6월 급여", how: 2_800_000, isRevenue: true))
        context.insert(FinDataEntity(when: day(10), towhat: "당근 판매", how: 45000, isRevenue: true))

        context.insert(FixedExpenditureEntity(day: 1, towhat: "월세", how: 550_000))
        context.insert(FixedExpenditureEntity(day: 15, towhat: "유튜브 프리미엄", how: 10450))
        context.insert(FixedExpenditureEntity(day: 25, towhat: "통신비", how: 49500))

        // 프로필 / 정산 기간
        let profileDescriptor = FetchDescriptor<ProfileEntity>()
        let profileEntity = (try? context.fetch(profileDescriptor))?.first ?? {
            let e = ProfileEntity(); context.insert(e); return e
        }()
        profileEntity.nickName = "두산"
        profileEntity.outLay = 600_000
        profileEntity.period = "1일"

        let periodDescriptor = FetchDescriptor<SalaryPeriodEntity>()
        let periodEntity = (try? context.fetch(periodDescriptor))?.first ?? {
            let e = SalaryPeriodEntity(); context.insert(e); return e
        }()
        periodEntity.startDate = Date().startOfThisMonth
        periodEntity.endDate = Date().endOfThisMonth

        try? context.save()
        UserDefaults.standard.setValue(true, forKey: "firstOpen")
    }
    #endif
    
    func sceneDidDisconnect(_ scene: UIScene) {
        
    }
    
    // 액티브 상태가 되었을 경우
    func sceneDidBecomeActive(_ scene: UIScene) {
        callBackgroundImage(false)
        
        if UIApplication.shared.applicationIconBadgeNumber != 0 {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
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

