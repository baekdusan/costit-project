import Foundation
import SwiftData

// Xcode Preview / 시뮬레이터 디자인 검증용 데모 데이터.
// - Preview: `PreviewSampleData.container` (in-memory, 디스크에 안 남음)
// - 시뮬레이터: SceneDelegate가 `seed(into:)`를 실제 컨테이너에 적용
@MainActor
enum PreviewSampleData {

    // Preview 전용 in-memory 컨테이너 (데모 데이터 시드 완료 상태)
    // try!는 Preview 전용이라 허용 — 실기기/배포 경로에서는 실행되지 않음
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: FinDataEntity.self,
                 FixedExpenditureEntity.self,
                 ProfileEntity.self,
                 SalaryPeriodEntity.self,
            configurations: config
        )
        seed(into: ModelContext(container))
        return container
    }()

    // 데모 데이터 주입 (멱등 — 기존 지출/수입/고정 지출은 지우고 다시 채움)
    //
    // ⚠️ 이 함수는 컨테이너의 수입·지출·고정지출을 전부 삭제한다. SceneDelegate가
    // SEED_DEMO_DATA=1일 때 실제(App Group) 컨테이너에 적용하므로, DEBUG 빌드를 꽂은
    // 실기기에서 환경변수가 걸리면 사용자 데이터가 통째로 날아간다.
    // → 릴리스 빌드에서는 아예 컴파일되지 않게 하고, 실기기 DEBUG에서는
    //   호출부(SceneDelegate.seedDemoData)의 시뮬레이터 가드가 막는다.
    //   (여기를 시뮬레이터 전용으로 막으면 실기기 대상 빌드의 Xcode Preview가 빈 컨테이너가 된다)
    static func seed(into context: ModelContext) {
        #if !DEBUG
        _ = context
        #else
        try? context.delete(model: FinDataEntity.self)
        try? context.delete(model: FixedExpenditureEntity.self)

        let cal = Calendar(identifier: .gregorian)   // 프로젝트 규약: 날짜 산술은 gregorian 고정
        func day(_ d: Int) -> Date {
            cal.date(byAdding: .day, value: d - 1, to: Date().startOfThisMonth) ?? Date()
        }

        let expenses: [(Int, String, Int)] = [
            (1,  "스타벅스 아메리카노", 4500),
            (2,  "빠레뜨 한남 브런치", 38000),
            (3,  "GS25 야식거리", 8200),
            (4,  "올리브영 스킨케어", 23400),
            (6,  "점심 마라탕", 11000),
            (7,  "지하철 교통비 충전", 30000),
            (9,  "교보문고 책 3권", 41200),
            (11, "무신사 후드 집업", 58000),
            (13, "CGV 영화 + 팝콘", 27000),
            (15, "이마트 장보기", 47300),
            (18, "올리브영 + 다이소", 19800),
            (20, "친구 생일선물", 35000),
            (23, "병원 진료 + 약국", 12600),
        ]
        for (d, what, how) in expenses {
            context.insert(FinDataEntity(when: day(d), towhat: what, how: how, isRevenue: false))
        }

        context.insert(FinDataEntity(when: day(1),  towhat: "이번 달 급여", how: 2_800_000, isRevenue: true))
        context.insert(FinDataEntity(when: day(10), towhat: "당근마켓 판매", how: 45000, isRevenue: true))
        context.insert(FinDataEntity(when: day(18), towhat: "생일 용돈", how: 100_000, isRevenue: true))

        context.insert(FixedExpenditureEntity(day: 1,  towhat: "월세", how: 550_000))
        context.insert(FixedExpenditureEntity(day: 13, towhat: "유튜브 프리미엄", how: 14900))
        context.insert(FixedExpenditureEntity(day: 17, towhat: "헬스장 정기권", how: 89000))
        context.insert(FixedExpenditureEntity(day: 25, towhat: "통신비", how: 55000))

        // 프로필 / 정산 기간 (upsert)
        let profileDescriptor = FetchDescriptor<ProfileEntity>()
        let profileEntity = (try? context.fetch(profileDescriptor))?.first ?? {
            let e = ProfileEntity(); context.insert(e); return e
        }()
        profileEntity.nickName = "두산"
        profileEntity.outLay = 700_000
        profileEntity.period = "1일"

        let periodDescriptor = FetchDescriptor<SalaryPeriodEntity>()
        let periodEntity = (try? context.fetch(periodDescriptor))?.first ?? {
            let e = SalaryPeriodEntity(); context.insert(e); return e
        }()
        periodEntity.startDate = Date().startOfThisMonth
        periodEntity.endDate = Date().endOfThisMonth

        try? context.save()

        // 첫 실행 온보딩을 건너뛰고 메인 그리드가 바로 보이게
        UserDefaults.standard.setValue(true, forKey: AppKeys.firstOpen)
        #endif
    }
}
