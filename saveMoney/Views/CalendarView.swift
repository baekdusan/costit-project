import SwiftUI
import SwiftData

// calendarVC를 SwiftUI로 옮긴 버전 — FSCalendar 의존 제거.
// SwiftData에서 직접 쿼리하고, 검색(SearchView)/고정 지출(FixedExpenditureView)도
// 순수 SwiftUI 네비게이션으로 연결한다.
struct CalendarView: View {

    @Environment(\.dismiss) private var dismissView

    @Query(sort: \FinDataEntity.when, order: .reverse)
    private var allFin: [FinDataEntity]

    @Query private var fixedItems: [FixedExpenditureEntity]
    @Query private var profiles: [ProfileEntity]

    // mainVC가 현재 보고 있는 정산 기간
    let start: Date
    let end: Date

    @State private var selectedDate: Date = Date()
    @State private var displayedMonth: Date = Date().startOfThisMonth
    @State private var showFixedExpenditure: Bool = false

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f
    }()

    private func dayKey(_ date: Date) -> String {
        Self.dayKeyFormatter.string(from: date)
    }

    // MARK: - 파생 데이터

    private var expenses: [FinDataEntity] { allFin.filter { !$0.isRevenue } }
    private var revenues: [FinDataEntity] { allFin.filter { $0.isRevenue } }

    // 날짜(yyyyMMdd)별 지출 총액 — 달력 점 색상 계산용
    private var expenseTotalsByDay: [String: Int] {
        var totals: [String: Int] = [:]
        for item in expenses {
            totals[dayKey(item.when), default: 0] += item.how
        }
        return totals
    }

    private var revenueDays: Set<String> {
        Set(revenues.map { dayKey($0.when) })
    }

    // 기간 내 수입/지출 총액
    private var periodRevenueTotal: Int {
        revenues.filter { $0.when >= start && $0.when <= end }.reduce(0) { $0 + $1.how }
    }

    private var periodExpenseTotal: Int {
        expenses.filter { $0.when >= start && $0.when <= end }.reduce(0) { $0 + $1.how }
    }

    private var fixedTotal: Int {
        fixedItems.reduce(0) { $0 + $1.how }
    }

    // 선택 날짜의 내역 (시간 내림차순)
    private var selectedItems: [FinDataEntity] {
        let key = dayKey(selectedDate)
        return allFin.filter { dayKey($0.when) == key }
    }

    private var selectedExpenseTotal: Int {
        selectedItems.filter { !$0.isRevenue }.reduce(0) { $0 + $1.how }
    }

    private var selectedRevenueTotal: Int {
        selectedItems.filter { $0.isRevenue }.reduce(0) { $0 + $1.how }
    }

    // 남은 기간 타이틀 (기존 calendarVC.setNavigationBar와 동일)
    private var ddayTitle: String {
        let dday = Calendar.current.dateComponents([.month, .day], from: Date(), to: end).day ?? 0
        switch dday {
        case 0: return "오늘이 마지막이에요!"
        case 1: return "하루 남았어요"
        default: return "\(dday)일 남았어요"
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let calendarWidth = proxy.size.width - 60

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        totalsBar
                            .padding(.top, 30)
                            .padding(.horizontal, 10)

                        calendarBlock(width: calendarWidth)
                            .padding(.top, 50)

                        dailyCard
                            .padding(.top, 30)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                }
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        NavigationLink {
                            SearchView()
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color("customLabel"))
                        }

                        Button {
                            showFixedExpenditure = true
                        } label: {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(Color("customLabel"))
                        }
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(ddayTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color("customLabel"))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismissView()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color("customLabel"))
                    }
                }
            }
            .fullScreenCover(isPresented: $showFixedExpenditure) {
                FixedExpenditureView()
            }
        }
    }

    // MARK: - 수입 / 지출 / 고정 지출 총액 바

    private var totalsBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                totalColumn(title: "수입 💰", value: periodRevenueTotal)
                totalColumn(title: "지출 💸", value: periodExpenseTotal)
                totalColumn(title: "고정 지출 📌", value: fixedTotal)
            }

            Rectangle()
                .fill(Color(uiColor: .systemGray6))
                .frame(height: 1.5)
                .padding(.horizontal, 10)
                .padding(.top, 18)
        }
    }

    private func totalColumn(title: String, value: Int) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.custom("PretendardVariable-SemiBold", size: 12))
                .foregroundStyle(Color("customLabel"))
            Text(value.toDecimal())
                .font(.custom("PretendardVariable-Bold", size: 16))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 달력 블록 (테이프 이미지 + 배경 매트 + 월 그리드)

    private func calendarBlock(width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // 테이프 이미지가 매트 위로 겹치는 영역
                Color.clear.frame(height: 10)

                MonthCalendarGrid(
                    displayedMonth: $displayedMonth,
                    selectedDate: $selectedDate,
                    periodStart: start,
                    periodEnd: end,
                    expenseTotalsByDay: expenseTotalsByDay,
                    revenueDays: revenueDays,
                    dailyBudget: dailyBudget
                )
                .frame(width: width)
                .padding(.top, 13)
                .padding(.bottom, 10)
                .padding(.horizontal, 10)
                .background(Color("calendarBgColor"))
            }

            Image("calendarTop")
                .resizable()
                .scaledToFit()
                .frame(width: width)
        }
    }

    // 일일 예산 (프로필 한 달 지출 목표 / 이번 달 일수) — 기존 percent()와 동일
    private var dailyBudget: Int {
        let daysInMonth = Int(Date().endOfThisMonth.onlydate()) ?? 30
        let outLay = profiles.first?.outLay ?? 0
        return daysInMonth > 0 ? outLay / daysInMonth : 0
    }

    // MARK: - 선택 날짜 상세 카드

    private var dailyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 상단: 날짜 (좌) + 수입 총액 (우, 파란색)
            HStack(alignment: .center) {
                Text(selectedDate.onlydate())
                    .font(.custom("AppleSDGothicNeo-Bold", size: 30))

                Spacer()

                Text("+ \(selectedRevenueTotal.toDecimal()) 원")
                    .font(.custom("AppleSDGothicNeo-SemiBold", size: 20))
                    .foregroundStyle(Color(uiColor: .systemBlue))
                    .opacity(revenueVisible ? 1 : 0)
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)

            // 선택 날짜 내역 목록 (높이 고정, 내부 스크롤 — 기존 테이블 뷰와 동일)
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(selectedItems) { item in
                        HStack {
                            Text(item.towhat)
                                .font(.system(size: 16, weight: .medium))
                                .opacity(0.78)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text((item.isRevenue ? "+ " : "- ") + item.how.toDecimal())
                                .font(.system(size: 18, weight: .semibold))
                                .opacity(0.84)
                        }
                        .frame(height: 60)
                    }
                }
            }
            .frame(height: 240)
            .padding(.top, 8)
            .padding(.horizontal, 20)

            // 하단: 지출 총액 (우)
            HStack {
                Spacer()
                Text("- \(selectedExpenseTotal.toDecimal()) 원")
                    .font(.custom("AppleSDGothicNeo-Bold", size: 22))
                    .opacity(expenseVisible ? 1 : 0)
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color("backgroundColor"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 6, y: -4)
    }

    // 기존 selectDate()의 알파 규칙: 양쪽 다 0이면 둘 다 표시, 한쪽만 있으면 그쪽만 표시
    private var expenseVisible: Bool {
        selectedExpenseTotal > 0 || (selectedExpenseTotal == 0 && selectedRevenueTotal == 0)
    }

    private var revenueVisible: Bool {
        selectedRevenueTotal > 0 || (selectedExpenseTotal == 0 && selectedRevenueTotal == 0)
    }
}

// MARK: - 월 달력 그리드 (FSCalendar 대체)

struct MonthCalendarGrid: View {

    @Binding var displayedMonth: Date   // 표시 중인 달 (그 달의 시작일)
    @Binding var selectedDate: Date

    let periodStart: Date
    let periodEnd: Date
    let expenseTotalsByDay: [String: Int]
    let revenueDays: Set<String>
    let dailyBudget: Int

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f
    }()

    private static let headerFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy년 M월"
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()

    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

    // 수입 점 파란색 / 기간 밖 지출 점 회색 (기존 colorLiteral과 동일 값)
    private let revenueDotColor = Color(red: 0.1765, green: 0.4980, blue: 0.7569)
    private let outOfPeriodDotColor = Color(red: 0.2549, green: 0.2745, blue: 0.3020)

    private var calendar: Calendar {
        Calendar(identifier: .gregorian)
    }

    // 일요일 시작으로 주 단위 분할 (빈 칸은 nil)
    private var weeks: [[Date?]] {
        let firstDay = displayedMonth.startOfThisMonth
        guard let range = calendar.range(of: .day, in: .month, for: firstDay) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstDay)

        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: firstDay))
        }
        while days.count % 7 != 0 { days.append(nil) }

        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0 ..< $0 + 7]) }
    }

    var body: some View {
        VStack(spacing: 4) {
            // 헤더: yyyy년 M월
            Text(Self.headerFormatter.string(from: displayedMonth))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color("customLabel"))
                .frame(height: 36)

            // 요일 줄
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color("customLabel"))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 30)

            // 날짜 그리드
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                        if let date {
                            dayCell(date)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        // 좌우 스와이프로 월 이동 (FSCalendar의 가로 스크롤 대체)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    let delta = value.translation.width < 0 ? 1 : -1
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
                    }
                }
        )
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 3) {
                Text(title(for: date))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("customLabel"))
                    .frame(width: 36, height: 28)
                    .background {
                        if isSelected {
                            Circle().fill(Color("calendarBgColor"))
                                .frame(width: 32, height: 32)
                        }
                    }

                // 이벤트 점: 수입(파랑) + 지출(예산 대비 강도별 핑크)
                HStack(spacing: 3) {
                    if revenueDays.contains(dayKey(date)) {
                        Circle().fill(revenueDotColor).frame(width: 6, height: 6)
                    }
                    if expenseTotalsByDay[dayKey(date)] != nil {
                        Circle().fill(expenseDotColor(for: date)).frame(width: 6, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
        }
        .buttonStyle(.plain)
    }

    private func dayKey(_ date: Date) -> String {
        Self.dayKeyFormatter.string(from: date)
    }

    // 기간 시작/끝/오늘은 숫자 대신 라벨 표시 (기존 calendar(_:titleFor:)와 동일)
    private func title(for date: Date) -> String {
        switch date.toFullString() {
        case periodStart.toFullString():
            return "시작"
        case periodEnd.toFullString():
            return "끝"
        case Date().toFullString():
            return "오늘"
        default:
            return date.onlydate()
        }
    }

    // 지출 점 색상 — 일일 예산 대비 강도 (기존 event()와 동일)
    private func expenseDotColor(for date: Date) -> Color {
        guard date >= periodStart && date <= periodEnd else {
            return outOfPeriodDotColor
        }

        let total = expenseTotalsByDay[dayKey(date)] ?? 0
        if total > Int(Double(dailyBudget) * 1.5) {
            return Color(uiColor: .systemPink)
        } else if total > dailyBudget {
            return Color(uiColor: .systemPink).opacity(0.6)
        } else {
            return Color(uiColor: .systemPink).opacity(0.2)
        }
    }
}

#Preview {
    CalendarView(start: Date().startOfThisMonth, end: Date().endOfThisMonth)
        .modelContainer(PreviewSampleData.container)
}
