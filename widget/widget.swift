import WidgetKit
import SwiftUI
import SwiftData

// 위젯 타임라인 항목. SwiftData에서 직접 계산한 표시용 값들을 담는다.
struct CostEntry: TimelineEntry {
    let date: Date
    let nickname: String
    let remaining: Int
    let outLay: Int
    let isOver: Bool
    // 0~100 사이의 잔여 비율 (정수, %)
    var percent: Int {
        guard outLay > 0 else { return 0 }
        let raw = Double(remaining) / Double(outLay) * 100
        return max(0, min(100, Int(raw.rounded())))
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> CostEntry {
        CostEntry(date: Date(), nickname: "User", remaining: 0, outLay: 0, isOver: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (CostEntry) -> ()) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CostEntry>) -> ()) {
        // 매일 자정에 위젯이 갱신되도록 두 항목만 전달.
        // 그 외 갱신은 앱이 WidgetCenter.shared.reloadAllTimelines()로 트리거.
        let now = Date()
        // 날짜 산술은 프로젝트 전체가 gregorian 고정 (비양력 기기에서도 동일하게 동작)
        let nextMidnight = Calendar(identifier: .gregorian).nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60 * 60 * 24)

        let entry = loadEntry(date: now)
        let nextEntry = loadEntry(date: nextMidnight)
        completion(Timeline(entries: [entry, nextEntry], policy: .atEnd))
    }

    private func loadEntry(date: Date = Date()) -> CostEntry {
        let context = ModelContext(PersistenceController.shared)

        // fetchLimit 1로 아무 행이나 집으면, CloudKit 경합으로 프로필이 여러 벌일 때
        // 앱과 위젯이 서로 다른 예산·급여일을 표시한다 → 앱과 같은 canonical 선택 규칙을 쓴다
        let profileEntity = (try? context.fetch(FetchDescriptor<ProfileEntity>()))?.canonical

        // 엔티티 없을 때 기본값은 앱과 동일하게 Profile()/SalaryDate()를 단일 소스로 사용
        let profile = profileEntity?.asProfile ?? Profile()

        // 정산 기간 갱신(rollover)은 앱의 MainView에서만 일어난다. 저장된 SalaryPeriodEntity는
        //  - 앱을 켜지 않은 채 급여일이 지나면 만료된 기간이고
        //  - 구버전 로직이 계산해 넣은 잘못된 값일 수도 있다.
        // 프로필이 있으면 앱과 같은 계산식으로 현재 기간을 직접 구해 항상 일치시킨다.
        // 프로필이 없으면 급여일을 알 수 없으므로 저장값(또는 기본값)을 그대로 쓴다.
        // (표시 전용 — 위젯은 저장하지 않는다)
        let period: SalaryDate
        if profileEntity != nil {
            period = SalaryDate.period(forSalaryDay: profile.period, now: date)
        } else {
            period = (try? context.fetch(FetchDescriptor<SalaryPeriodEntity>()))?.canonical?.asSalaryDate ?? SalaryDate()
        }

        let start = period.startDate
        // end(23:59:59)에 `<=`를 쓰면 소수초를 가진 레코드가 기간 사이로 빠진다 → 반열린 구간 (앱과 동일)
        let upperBound = period.endDate.addingTimeInterval(1)

        let predicate = #Predicate<FinDataEntity> {
            $0.isRevenue == false && $0.when >= start && $0.when < upperBound
        }
        let expenses = (try? context.fetch(FetchDescriptor<FinDataEntity>(predicate: predicate))) ?? []
        let total = expenses.reduce(0) { $0 + $1.how }

        return CostEntry(
            date: date,
            nickname: profile.nickName,
            remaining: profile.outLay - total,
            outLay: profile.outLay,
            // 예산이 0이면 "초과"가 아니라 "아직 설정 전"이다. total(0) >= outLay(0)로 판정하면
            // 앱을 아직 열지 않아 데이터를 못 읽은 상태(레거시 이전 전 / CloudKit 동기화 전)에도
            // "망했어요 · 😱 · 빨간 게이지"가 떠서, 실제 데이터가 멀쩡한데 초과한 것처럼 보인다.
            isOver: profile.outLay > 0 && total >= profile.outLay
        )
    }
}

struct CostItWidgetEntryView: View {
    var entry: CostEntry

    @ViewBuilder
    var body: some View {
        let percent = entry.percent
        let color: Color = percent > 50
            ? Color(#colorLiteral(red: 0.3518846035, green: 0.6747873425, blue: 0.622913003, alpha: 1))
            : (percent > 20
                ? Color(#colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1))
                : Color(#colorLiteral(red: 0.9464814067, green: 0.240496546, blue: 0.2090002298, alpha: 1)))
        let emoji: String = percent >= 80 ? "🤑"
            : percent >= 60 ? "😊"
            : percent >= 40 ? "🙂"
            : percent >= 20 ? "🤔" : "😱"

        GeometryReader { geometry in
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(entry.nickname)님")
                    .font(.system(size: 12, weight: .bold))
                    .frame(height: geometry.size.height * 0.1)
                    .opacity(0.72)

                // 앱과 같은 ko_KR 고정 포맷(Int.toDecimal) — .formatted(.number)는 기기 로케일을 따라
                // 비한국 로케일에서 앱과 구분자가 달라진다
                Text(verbatim: "\(entry.remaining.toDecimal())원")
                    .font(.system(size: 24, weight: .bold))
                    .frame(height: geometry.size.height * 0.2)
                    .opacity(0.84)
                    .minimumScaleFactor(0.72)

                Text(entry.isOver ? "망했어요" : "남았어요")
                    .font(.system(size: 12, weight: .bold))
                    .frame(height: geometry.size.height * 0.1)
                    .opacity(0.72)

                HStack(alignment: .bottom, spacing: 0) {
                    Text(verbatim: "\(percent)%")
                        .font(.system(size: 28, weight: .semibold))
                        .frame(width: geometry.size.width * 0.45, alignment: .leading)
                        .opacity(0.84)
                        .minimumScaleFactor(0.72)
                    Text(emoji)
                        .font(.system(size: 30))
                        .frame(width: geometry.size.width * 0.45, alignment: .trailing)
                }
                .frame(width: geometry.size.width * 0.9,
                       height: geometry.size.height * 0.32,
                       alignment: .bottom)
            }
            .frame(width: geometry.size.width,
                   height: geometry.size.height * 0.92,
                   alignment: .center)

            ZStack(alignment: .leading) {
                Color(.widgetStatusBarBackground)
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.08)
                color
                    .frame(width: geometry.size.width * CGFloat(percent) / 100,
                           height: geometry.size.height * 0.08)
            }
            .frame(width: geometry.size.width,
                   height: geometry.size.height,
                   alignment: .bottom)
        }
        .containerBackground(Color(.widgetBackground), for: .widget)
    }
}

@main
struct CostItWidget: Widget {
    // 홈 화면에 이미 배치된 위젯의 영속 식별자 — 값을 바꾸면 기존 위젯이 사라지므로 변경 금지
    let kind: String = "widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CostItWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("코스트잇")
        .description("나의 코스트 배터리는 몇% 남았을까요?")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    CostItWidget()
} timeline: {
    CostEntry(
        date: Date(),
        nickname: "User",
        remaining: 130_000,
        outLay: 260_000,
        isOver: false
    )
}
