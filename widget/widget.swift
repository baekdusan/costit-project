import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct widgetEntryView : View {
    var entry: Provider.Entry
    
    @ViewBuilder
    var body: some View {
        let wdata = UserDefaults.init(suiteName: "group.costit")?.stringArray(forKey: "string") ?? ["User", "0원", "지출 추가하기", "0"]
        let condition = Double(wdata[3])! / 100
        let int = condition * 100
        let color: CGColor = int > 20 ? ( int > 50 ? #colorLiteral(red: 0.3518846035, green: 0.6747873425, blue: 0.622913003, alpha: 1) : #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)) : #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)
        let emoji: String = int >= 20 ? (int >= 40 ? (int >= 60 ? (int >= 80 ? "🤑" : "😊") : "🙂") : "🤔") : "😱"
        GeometryReader { geometry in
            Color("HeaderColor")
                .opacity(0.25)
            VStack(alignment: .trailing) {
                Text(wdata[0])
                    .font(.system(size: 12, weight: .bold))
                    .frame(height: geometry.size.height * 0.1)
                    .foregroundColor(Color("customLabel"))
                Text(wdata[1])
                    .font(.system(size: 24, weight: .bold))
                    .frame(height: geometry.size.height * 0.2)
                Text(wdata[2])
                    .font(.system(size: 12, weight: .bold))
                    .frame(height: geometry.size.height * 0.1)
                    .foregroundColor(Color("customLabel"))
                HStack(alignment: .bottom) {
                    Text(wdata[3] + "%")
                        .foregroundColor(Color("customLabel"))
                        .font(.system(size: 28, weight: .semibold))
                        .frame(width: geometry.size.width * 0.55, height: nil, alignment: .leading)
                    Text(emoji)
                        .font(.system(size: 30))
                        .frame(width: geometry.size.width * 0.25, height: nil, alignment: .trailing)
                }.frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.3, alignment: .bottom)
            }.frame(width: geometry.size.width, height: geometry.size.height * 0.9, alignment: .center)
            ZStack(alignment: .leading) {
                Color("toolbar")
                    .frame(width: geometry.size.width , height: geometry.size.height * 0.08)
                Color(color)
                    .frame(width: geometry.size.width * CGFloat(condition) , height: geometry.size.height * 0.08)
            }.frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
        }
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
    }
}

struct widget_Previews: PreviewProvider {
    static var previews: some View {
        widgetEntryView(entry: SimpleEntry(date: Date()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
