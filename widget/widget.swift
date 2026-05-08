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
        let nextMidnight = Calendar.current.nextDate(
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

        let profile = (try? context.fetch(FetchDescriptor<ProfileEntity>()))?.first
        let salary = (try? context.fetch(FetchDescriptor<SalaryPeriodEntity>()))?.first

        let nickname = profile?.nickName ?? "User"
        let outLay = profile?.outLay ?? 0

        let start = salary?.startDate ?? Date().startOfThisMonth
        let end = salary?.endDate ?? Date().endOfThisMonth

        let predicate = #Predicate<FinDataEntity> {
            $0.isRevenue == false && $0.when >= start && $0.when <= end
        }
        let expenses = (try? context.fetch(FetchDescriptor<FinDataEntity>(predicate: predicate))) ?? []
        let total = expenses.reduce(0) { $0 + $1.how }

        let remaining = outLay - total
        let isOver = total >= outLay

        return CostEntry(
            date: date,
            nickname: nickname,
            remaining: remaining,
            outLay: outLay,
            isOver: isOver
        )
    }
}

struct widgetEntryView: View {
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

                Text("\(entry.remaining.formatted(.number))원")
                    .font(.system(size: 24, weight: .bold))
                    .frame(height: geometry.size.height * 0.2)
                    .opacity(0.84)
                    .minimumScaleFactor(0.72)

                Text(entry.isOver ? "망했어요" : "남았어요")
                    .font(.system(size: 12, weight: .bold))
                    .frame(height: geometry.size.height * 0.1)
                    .opacity(0.72)

                HStack(alignment: .bottom, spacing: 0) {
                    Text("\(percent)%")
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
                Color("WidgetStatusBarBackground")
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.08)
                color
                    .frame(width: geometry.size.width * CGFloat(percent) / 100,
                           height: geometry.size.height * 0.08)
            }
            .frame(width: geometry.size.width,
                   height: geometry.size.height,
                   alignment: .bottom)
        }
        .widgetBackground(Color("WidgetBackground"))
    }
}

@main
struct widget: Widget {
    let kind: String = "widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            widgetEntryView(entry: entry)
        }
        .configurationDisplayName("코스트잇")
        .description("나의 코스트 배터리는 몇% 남았을까요?")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabledIfAvailable()
    }
}

struct widget_Previews: PreviewProvider {
    static var previews: some View {
        widgetEntryView(entry: CostEntry(
            date: Date(),
            nickname: "User",
            remaining: 130_000,
            outLay: 260_000,
            isOver: false
        ))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}

extension View {
    func widgetBackground(_ backgroundColor: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            return self.containerBackground(backgroundColor, for: .widget)
        } else {
            return self.background(backgroundColor)
        }
    }
}

extension WidgetConfiguration {
    func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration {
        if #available(iOSApplicationExtension 17.0, *) {
            return self.contentMarginsDisabled()
        } else { return self }
    }
}
