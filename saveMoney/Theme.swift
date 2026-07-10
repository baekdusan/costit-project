import SwiftUI

// MARK: - 폰트 토큰
// "PretendardVariable-*" 문자열 리터럴 오타를 컴파일 타임에 차단하기 위한 토큰.
// (색상은 asset catalog 자동 생성 심볼 Color(.customLabel) 등을 직접 사용)
// CalendarView dailyCard의 AppleSDGothicNeo 3곳은 레거시 디자인 보존 의도로 보여
// 토큰화하지 않고 유지 — Pretendard 통일 여부는 디자인 판단 대기.

extension Font {
    enum PretendardWeight: String {
        case regular = "Regular"
        case medium = "Medium"
        case semiBold = "SemiBold"
        case bold = "Bold"
        case extraBold = "ExtraBold"
    }

    static func pretendard(_ weight: PretendardWeight, size: CGFloat) -> Font {
        .custom("PretendardVariable-\(weight.rawValue)", size: size)
    }
}
