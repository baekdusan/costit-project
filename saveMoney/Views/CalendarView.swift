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

    @State private var selectedDate: Date = {
        #if DEBUG
        // 디자인 검증/스크린샷 캡처 시 결제 있는 날(이번 달 13일)을 미리 선택해
        // 하단에 해당 날짜 내역이 보이도록 한다.
        if ProcessInfo.processInfo.environment[LaunchEnvKeys.showScreen] == "calendar" {
            return Calendar.current.date(byAdding: .day, value: 12, to: Date().startOfThisMonth) ?? Date()
        }
        #endif
        return Date()
    }()
    @State private var displayedMonth: Date = Date().startOfThisMonth
    @State private var showFixedExpenditure: Bool = false

    // MARK: - 파생 데이터

    private var expenses: [FinDataEntity] { allFin.filter { !$0.isRevenue } }
    private var revenues: [FinDataEntity] { allFin.filter { $0.isRevenue } }

    // 날짜(그 날 00:00)별 그룹핑 — 모든 일 단위 파생의 단일 소스 (MainView.sections와 동일 규칙)
    private var itemsByDay: [Date: [FinDataEntity]] {
        Dictionary(grouping: allFin) { $0.when.startOfDay }
    }

    // 날짜별 지출 총액 — 달력 점 색상 계산용.
    // 지출 항목이 없는 날은 엔트리 자체가 없어야 함 (수입만 있는 날에 지출 점이 찍히면 안 됨)
    private var expenseTotalsByDay: [Date: Int] {
        itemsByDay.compactMapValues { items in
            let dayExpenses = items.filter { !$0.isRevenue }
            return dayExpenses.isEmpty ? nil : dayExpenses.reduce(0) { $0 + $1.how }
        }
    }

    private var revenueDays: Set<Date> {
        Set(itemsByDay.filter { $0.value.contains { $0.isRevenue } }.keys)
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

    // 선택 날짜의 내역 (@Query 정렬 순서 유지 — 시간 내림차순)
    private var selectedItems: [FinDataEntity] {
        itemsByDay[selectedDate.startOfDay] ?? []
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
                // 초기 레이아웃 패스에서 proxy.size.width가 0이면 음수가 되어
                // .frame(width:)에 "Invalid frame dimension" 경고가 발생하므로 방어
                let calendarWidth = max(0, proxy.size.width - 60)

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
                    NavigationLink {
                        SearchView()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color(.customLabel))
                    }
                }

                // iOS 26 toolbar는 같은 placement 버튼을 한 캡슐로 묶으므로
                // ToolbarSpacer로 분리해 각각 독립 원형 버튼으로 표시
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarLeading)
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFixedExpenditure = true
                    } label: {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(Color(.customLabel))
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(ddayTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(.customLabel))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismissView()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color(.customLabel))
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

            HairlineDivider()
                .padding(.horizontal, 10)
                .padding(.top, 18)
        }
    }

    private func totalColumn(title: String, value: Int) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.pretendard(.semiBold, size: 14))
                .foregroundStyle(Color(.customLabel))
            Text(value.toDecimal())
                .font(.pretendard(.bold, size: 16))
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

                // 기존 스토리보드 구조: 달력 본체는 backgroundColor,
                // calendarBgColor는 주변 매트(상단 20 / 좌우·하단 10) 테두리로만 보임
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
                .background(Color(.background))
                .padding(.top, 20)
                .padding(.bottom, 10)
                .padding(.horizontal, 10)
                .background(Color(.calendarBg))
            }

            Image("calendarTop")
                .resizable()
                .scaledToFit()
                .frame(width: width)
                // 스프링 구멍이 종이 윗변에 닿아 얕게 뚫린 느낌이라 살짝 내림
                .offset(y: 2)
        }
    }

    // 일일 예산 (프로필 한 달 지출 목표 / 이번 달 일수) — 기존 percent()와 동일
    private var dailyBudget: Int {
        let daysInMonth = Int(Date().endOfThisMonth.onlydate()) ?? 30
        let outLay = (profiles.first?.asProfile ?? Profile()).outLay
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
                            // 스토리보드(calendarVC 테이블 셀): system 16/18, weight 미지정(regular)
                            Text(item.towhat)
                                .font(.system(size: 16))
                                .opacity(0.78)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text((item.isRevenue ? "+ " : "- ") + item.how.toDecimal())
                                .font(.system(size: 18))
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
        .background(Color(.background))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .paperShadow(y: -4)
    }

    // 기존 selectDate()의 알파 규칙: 양쪽 다 0이면 둘 다 표시, 한쪽만 있으면 그쪽만 표시
    private var expenseVisible: Bool {
        selectedExpenseTotal > 0 || (selectedExpenseTotal == 0 && selectedRevenueTotal == 0)
    }

    private var revenueVisible: Bool {
        selectedRevenueTotal > 0 || (selectedExpenseTotal == 0 && selectedRevenueTotal == 0)
    }
}

#Preview {
    CalendarView(start: Date().startOfThisMonth, end: Date().endOfThisMonth)
        .modelContainer(PreviewSampleData.container)
}
