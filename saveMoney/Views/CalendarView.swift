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

    // 화면에 필요한 모든 파생값을 전건 1회 순회로 한 번에 만든다.
    //
    // 과거엔 expenses/revenues/itemsByDay/expenseTotalsByDay/revenueDays/기간합계가 각각
    // 독립 computed였고, body 한 번에 전건을 다섯 번 넘게 훑으면서 startOfDay도 항목 수만큼
    // 다시 계산했다. 이 body는 날짜 셀 탭과 월 스와이프마다 재평가되므로 수년치 데이터에서는
    // 탭 반응이 눈에 띄게 늦어진다.
    private struct DayAggregates {
        var itemsByDay: [Date: [FinDataEntity]] = [:]
        // 지출 항목이 없는 날은 엔트리 자체가 없어야 한다 (수입만 있는 날에 지출 점이 찍히면 안 됨)
        var expenseTotalsByDay: [Date: Int] = [:]
        var revenueDays: Set<Date> = []
        var periodExpenseTotal: Int = 0
        var periodRevenueTotal: Int = 0
    }

    private func makeAggregates() -> DayAggregates {
        // end(23:59:59)에 `<=`를 쓰면 소수초를 가진 레코드가 기간 사이로 빠진다 → 반열린 구간 (다른 화면과 동일)
        let upperBound = end.addingTimeInterval(1)
        var result = DayAggregates()

        for item in allFin {
            let day = item.when.startOfDay
            result.itemsByDay[day, default: []].append(item)

            let inPeriod = item.when >= start && item.when < upperBound
            if item.isRevenue {
                result.revenueDays.insert(day)
                if inPeriod { result.periodRevenueTotal += item.how }
            } else {
                result.expenseTotalsByDay[day, default: 0] += item.how
                if inPeriod { result.periodExpenseTotal += item.how }
            }
        }
        return result
    }

    private var fixedTotal: Int {
        fixedItems.reduce(0) { $0 + $1.how }
    }

    // 남은 기간 타이틀
    private var ddayTitle: String {
        // [.month, .day]로 요청하면 day에 월을 뺀 나머지만 담겨 30일 이상 스팬에서 오표시 → [.day]만 사용
        // 날짜 산술은 프로젝트 전체가 gregorian 고정
        //
        // 양끝을 그 날 00:00으로 내려 "며칠 남았는가"를 달력 날짜 차이로 센다.
        // 시각을 그대로 넣으면 dateComponents가 24시간 단위 몫을 주기 때문에,
        // 마지막 날 하루가 24시간이 아닌 날(서머타임 도입일 23시간)에는 남은 날짜가
        // 하루 적게 나와 아직 하루 남았는데도 "오늘이 마지막이에요!"가 뜬다.
        let calendar = Calendar(identifier: .gregorian)
        let dday = max(0, calendar.dateComponents([.day], from: Date().startOfDay, to: end.startOfDay).day ?? 0)
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
                // 전건 순회는 body 평가당 한 번만 (선택 날짜 내역도 여기서 유도)
                let aggregates = makeAggregates()
                let selectedItems = aggregates.itemsByDay[selectedDate.startOfDay] ?? []

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        totalsBar(aggregates: aggregates)
                            .padding(.top, 30)
                            .padding(.horizontal, 10)

                        calendarBlock(width: calendarWidth, aggregates: aggregates)
                            .padding(.top, 50)

                        dailyCard(items: selectedItems)
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

    private func totalsBar(aggregates: DayAggregates) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                totalColumn(title: "수입 💰", value: aggregates.periodRevenueTotal)
                totalColumn(title: "지출 💸", value: aggregates.periodExpenseTotal)
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

    private func calendarBlock(width: CGFloat, aggregates: DayAggregates) -> some View {
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
                    expenseTotalsByDay: aggregates.expenseTotalsByDay,
                    revenueDays: aggregates.revenueDays,
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
        // 포매터 문자열 왕복 대신 Calendar 산술 (프로젝트 규약: 날짜 계산은 gregorian 고정)
        let daysInMonth = Calendar(identifier: .gregorian)
            .range(of: .day, in: .month, for: Date())?.count ?? 30
        let outLay = (profiles.canonical?.asProfile ?? Profile()).outLay
        return daysInMonth > 0 ? outLay / daysInMonth : 0
    }

    // MARK: - 선택 날짜 상세 카드

    private func dailyCard(items: [FinDataEntity]) -> some View {
        let expenseTotal = items.filter { !$0.isRevenue }.reduce(0) { $0 + $1.how }
        let revenueTotal = items.filter { $0.isRevenue }.reduce(0) { $0 + $1.how }
        // 기존 selectDate()의 알파 규칙: 양쪽 다 0이면 둘 다 표시, 한쪽만 있으면 그쪽만 표시
        let bothZero = expenseTotal == 0 && revenueTotal == 0
        let expenseVisible = expenseTotal > 0 || bothZero
        let revenueVisible = revenueTotal > 0 || bothZero

        return VStack(alignment: .leading, spacing: 0) {
            // 상단: 날짜 (좌) + 수입 총액 (우, 파란색)
            HStack(alignment: .center) {
                Text(selectedDate.onlydate())
                    .font(.custom("AppleSDGothicNeo-Bold", size: 30))

                Spacer()

                Text("+ \(revenueTotal.toDecimal()) 원")
                    .font(.custom("AppleSDGothicNeo-SemiBold", size: 20))
                    .foregroundStyle(Color(uiColor: .systemBlue))
                    .opacity(revenueVisible ? 1 : 0)
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)

            // 선택 날짜 내역 목록 (높이 고정, 내부 스크롤 — 기존 테이블 뷰와 동일)
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
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
                Text("- \(expenseTotal.toDecimal()) 원")
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
}

#Preview {
    CalendarView(start: Date().startOfThisMonth, end: Date().endOfThisMonth)
        .modelContainer(PreviewSampleData.container)
}
