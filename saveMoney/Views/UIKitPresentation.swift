import SwiftUI
import UIKit

// MARK: - UIKit 프레젠테이션 브리지
// AddFinView(투명 배경 overFullScreen)는 SwiftUI fullScreenCover 대신 UIKit present를 쓴다:
// cover는 배경 투명화가 어렵고, 과거 onChange 기반 표시는 편집→편집 연속 진입 시
// 발화하지 않는 버그가 있었다. RevenueView도 같은 이유(전체 화면 즉시 전환)로 UIKit present.

// 키 윈도우 탐색 — windows.first는 키보드/권한 다이얼로그 등 시스템 윈도우가 잡힐 수 있으므로
// isKeyWindow 기준으로 앱 윈도우를 찾는다.
extension UIApplication {
    var appKeyWindow: UIWindow? {
        let windows = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first
    }

    var appRootViewController: UIViewController? {
        appKeyWindow?.rootViewController
    }
}

extension UIViewController {
    // 모달 체인의 최상단 VC (present는 반드시 여기서 해야 함)
    var topMostPresentedViewController: UIViewController {
        var top = self
        while let next = top.presentedViewController {
            top = next
        }
        return top
    }
}

// 지출/수입 추가·수정 화면 present — MainView/RevenueView 공통 경로.
// 최상단 VC에서 present하고(이미 다른 모달 위에서도 동작 + RevenueView가 루트인 DEBUG 모드 지원),
// dismiss 진행 중인 VC 위에는 present하지 않는다.
@MainActor
func presentAddFin(source: AddFinView.Source, mode: AddFinView.Mode) {
    guard let root = UIApplication.shared.appRootViewController else { return }
    let presenter = root.topMostPresentedViewController
    guard !presenter.isBeingDismissed else { return }

    let view = AddFinView(source: source, mode: mode)
        .modelContainer(PersistenceController.shared)
        .dynamicTypeSize(.large)
    let host = UIHostingController(rootView: view)
    host.modalPresentationStyle = .overFullScreen
    host.view.backgroundColor = .clear
    presenter.present(host, animated: false)
}
