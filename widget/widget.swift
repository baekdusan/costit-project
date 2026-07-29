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
    let state: State

    // 표시 상태. "프로필이 없다"와 "데이터를 못 읽었다"를 합치면 안내 문구가 틀린다 —
    // 예산을 설정해둔 사용자가 일시적 조회 실패 때 "예산을 설정해주세요"를 보면
    // 프로필이 사라진 줄 알고 다시 입력하게 되고, 그때 급여일이 바뀌면 이전 기간 지출이
    // 화면에서 사라지는 후속 혼란까지 이어진다.
    enum State {
        case normal         // 정상 표시
        case needsSetup     // 프로필이 아직 없다 → 설정 안내
        case unavailable    // 데이터를 읽지 못했다 → 판단 불가(중립)
    }

    // 수치를 단정할 수 없는 상태 — 금액·비율·게이지·이모지를 모두 중립으로 둔다
    var isNeutral: Bool { state != .normal }

    // 예산이 0이면 "몇 % 남았는가"라는 개념이 성립하지 않는다. percent가 0으로 떨어지는 바람에
    // 이모지 😱와 빨간 게이지가 뜨는데 문구는 "남았어요"라 서로 반대를 말하게 된다.
    var hasNoBudget: Bool { outLay <= 0 }

    // 비율 기반 표현(색·이모지·비율 텍스트)을 쓸 수 없는 상태
    var ratioUnknown: Bool { isNeutral || hasNoBudget }

    // 0~100 사이의 잔여 비율 (정수, %)
    var percent: Int {
        guard outLay > 0 else { return 0 }
        let raw = Double(remaining) / Double(outLay) * 100
        return max(0, min(100, Int(raw.rounded())))
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> CostEntry {
        CostEntry(date: Date(), nickname: "User", remaining: 0, outLay: 0, isOver: false, state: .needsSetup)
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

        // 데이터를 못 읽은 실행은 "잠시 후 다시 볼게요"라고 안내하므로 실제로도 곧 재시도해야 한다.
        // .atEnd로 두면 몇 초짜리 일시 오류였어도 다음 자정까지 그 화면이 굳는다.
        guard entry.state != .unavailable else {
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(15 * 60))))
            return
        }

        let nextEntry = loadEntry(date: nextMidnight)
        completion(Timeline(entries: [entry, nextEntry], policy: .atEnd))
    }

    private func loadEntry(date: Date = Date()) -> CostEntry {
        let context = ModelContext(PersistenceController.shared)

        // fetchLimit 1로 아무 행이나 집으면, CloudKit 경합으로 프로필이 여러 벌일 때
        // 앱과 위젯이 서로 다른 예산·급여일을 표시한다 → 앱과 같은 canonical 선택 규칙을 쓴다
        //
        // 조회 실패(throw)와 "프로필이 아직 없음"을 구분해서 들고 간다. 뭉쳐서 nil로 만들면
        // 예산을 설정해둔 사용자가 일시적 조회 실패 때 "예산을 설정해주세요"를 보게 되고,
        // 그 화면은 .atEnd 정책이라 다음 자정까지 굳는다(재시도 정책은 unavailable에만 적용).
        let profileFetch = try? context.fetch(FetchDescriptor<ProfileEntity>())
        let profileEntity = profileFetch?.canonical

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
        // 지출 조회 실패를 "0건"으로 삼키면 예산을 다 쓴 사용자에게 "100% 남았어요 🤑"를 확신 있게
        // 보여주게 된다 → 실패는 "판단 불가"로 처리한다(프로필 미확보와 같은 중립 표시)
        let expenses = try? context.fetch(FetchDescriptor<FinDataEntity>(predicate: predicate))
        let total = (expenses ?? []).reduce(0) { $0 + $1.how }

        return CostEntry(
            date: date,
            nickname: profile.nickName,
            remaining: profile.outLay - total,
            outLay: profile.outLay,
            // 예산이 0이면 "초과"가 아니라 "아직 설정 전"이다. total(0) >= outLay(0)로 판정하면
            // 앱을 아직 열지 않아 데이터를 못 읽은 상태(레거시 이전 전 / CloudKit 동기화 전)에도
            // "망했어요 · 😱 · 빨간 게이지"가 떠서, 실제 데이터가 멀쩡한데 초과한 것처럼 보인다.
            // 예산 0원 사용자도 지출이 있으면 초과가 맞다. outLay > 0 가드만 두면
            // 잔액이 음수인데 문구는 영원히 "남았어요"가 되어 이모지·게이지와 반대를 말한다.
            isOver: total > 0 && total >= profile.outLay,
            // 조회 실패를 우선 판정한다 — 프로필까지 못 읽었다면 "설정 안내"가 아니라 "판단 불가"다.
            // isEphemeralFallback: 스토어를 못 열어 in-memory로 폴백하면 fetch는 성공하면서
            // 빈 결과를 준다. 이걸 "프로필 없음"으로 읽으면 예산을 설정해둔 사용자에게
            // "예산을 설정해주세요"가 떠서 프로필이 사라진 줄 알고 재입력하게 된다.
            // profileFetch == nil은 "프로필이 없다"가 아니라 "읽지 못했다"다.
            state: (expenses == nil || profileFetch == nil || PersistenceController.isEphemeralFallback) ? .unavailable
                 : (profileEntity == nil ? .needsSetup : .normal)
        )
    }
}

struct CostItWidgetEntryView: View {
    var entry: CostEntry

    @ViewBuilder
    var body: some View {
        let percent = entry.percent
        // 예산이 0원이라 "몇 % 남았는가"를 못 구해도, 지출이 있으면 초과인 것은 확실하다.
        // 그 경우까지 중립으로 두면 문구는 "망했어요"인데 이모지는 🙂, 게이지는 회색이라
        // 한 화면 안에서 서로 반대를 말하게 된다.
        // (예산이 있는 초과 사용자는 percent가 0이라 아래 비율 분기에서 이미 같은 결과가 나온다)
        let isDefinitelyOver = entry.state == .normal && entry.isOver
        // 예산 미설정 상태에서는 게이지·이모지도 중립으로 둔다. percent가 0이라는 이유로
        // 빨간 게이지와 😱를 쓰면, 데이터가 멀쩡한데 최악 상태인 것처럼 보인다.
        let color: Color = isDefinitelyOver
            ? Color(#colorLiteral(red: 0.9464814067, green: 0.240496546, blue: 0.2090002298, alpha: 1))
            : (entry.ratioUnknown
                ? Color(#colorLiteral(red: 0.6862745285, green: 0.6862745285, blue: 0.6862745285, alpha: 1))
                : (percent > 50
                    ? Color(#colorLiteral(red: 0.3518846035, green: 0.6747873425, blue: 0.622913003, alpha: 1))
                    : (percent > 20
                        ? Color(#colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1))
                        : Color(#colorLiteral(red: 0.9464814067, green: 0.240496546, blue: 0.2090002298, alpha: 1)))))
        let emoji: String = isDefinitelyOver ? "😱"
            : entry.ratioUnknown ? "🙂"
            : percent >= 80 ? "🤑"
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
                // 예산 미설정이면 "남은 금액"이라는 개념 자체가 없다.
                // 그대로 두면 지출만 동기화된 순간 "-50,000원 남았어요" 같은 모순이 표시된다.
                Text(verbatim: entry.isNeutral ? "-" : "\(entry.remaining.toDecimal())원")
                    .font(.system(size: 24, weight: .bold))
                    .frame(height: geometry.size.height * 0.2)
                    .opacity(0.84)
                    .minimumScaleFactor(0.72)

                Text(entry.state == .needsSetup ? "예산을 설정해주세요"
                     : entry.state == .unavailable ? "잠시 후 다시 볼게요"
                     : (entry.isOver ? "망했어요" : "남았어요"))
                    .font(.system(size: 12, weight: .bold))
                    .frame(height: geometry.size.height * 0.1)
                    .opacity(0.72)

                HStack(alignment: .bottom, spacing: 0) {
                    // 미설정 상태에서 "0%"를 띄우면 예산을 다 쓴 것처럼 읽힌다
                    // (금액을 "-"로 가려놓고 비율만 0으로 단정하는 자기모순이기도 하다)
                    Text(verbatim: entry.ratioUnknown ? "-" : "\(percent)%")
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
                    // 판단 불가 상태에서 percent(= remaining/outLay)는 조회 실패로 100이 될 수 있다.
                    // 금액·비율을 "-"로 가려놓고 게이지만 만수위로 그리면 자기모순이 된다.
                    .frame(width: entry.ratioUnknown ? 0 : geometry.size.width * CGFloat(percent) / 100,
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
        isOver: false,
        state: .normal
    )
}
