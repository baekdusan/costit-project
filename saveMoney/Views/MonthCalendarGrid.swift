import SwiftUI

// MARK: - 월 달력 그리드 (FSCalendar 대체)
// 일 단위 데이터는 그 날 00:00(startOfDay)을 키로 받는다 — CalendarView와 동일 규칙.

struct MonthCalendarGrid: View {

    @Binding var displayedMonth: Date   // 표시 중인 달 (그 달의 시작일)
    @Binding var selectedDate: Date

    // 월 전환 시 새 달이 들어오는 방향 (스와이프 방향에 맞춰 갱신)
    @State private var slideEdge: Edge = .trailing

    let periodStart: Date
    let periodEnd: Date
    let expenseTotalsByDay: [Date: Int]
    let revenueDays: Set<Date>
    let dailyBudget: Int

    private static let headerFormatter: DateFormatter = {
        let f = DateFormatter()
        // 그리드 숫자는 gregorian 산술로 만들므로 헤더도 같은 캘린더로 고정한다 —
        // 미지정이면 불교력 기기에서 헤더만 "2569년 7월"로 나온다
        f.calendar = Calendar(identifier: .gregorian)
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
        // 월 전체를 좌우로 슬라이드시켜 페이지 넘기는 느낌을 준다.
        gridContent
            .id(displayedMonth)
            .transition(.asymmetric(
                insertion: .move(edge: slideEdge).combined(with: .opacity),
                removal: .move(edge: slideEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
            ))
            .clipped()
            .contentShape(Rectangle())
            // 좌우 스와이프로 월 이동 (FSCalendar의 가로 스크롤 대체)
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        let delta = value.translation.width < 0 ? 1 : -1
                        slideEdge = delta > 0 ? .trailing : .leading
                        withAnimation(.easeInOut(duration: 0.28)) {
                            displayedMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
                        }
                    }
            )
    }

    private var gridContent: some View {
        VStack(spacing: 4) {
            // 헤더: yyyy년 M월
            Text(Self.headerFormatter.string(from: displayedMonth))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(.customLabel))
                .frame(height: 36)

            // 요일 줄
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(.customLabel))
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
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let dayStart = date.startOfDay

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 3) {
                Text(title(for: date))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.customLabel))
                    .frame(width: 36, height: 28)
                    .background {
                        if isSelected {
                            Circle().fill(Color(.calendarBg))
                                .frame(width: 32, height: 32)
                        }
                    }

                // 이벤트 점: 수입(파랑) + 지출(예산 대비 강도별 핑크)
                HStack(spacing: 3) {
                    if revenueDays.contains(dayStart) {
                        Circle().fill(revenueDotColor).frame(width: 6, height: 6)
                    }
                    if expenseTotalsByDay[dayStart] != nil {
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

    // 기간 시작/끝/오늘은 숫자 대신 라벨 표시 (검사 순서: 시작 > 끝 > 오늘)
    private func title(for date: Date) -> String {
        if calendar.isDate(date, inSameDayAs: periodStart) { return "시작" }
        if calendar.isDate(date, inSameDayAs: periodEnd) { return "끝" }
        if calendar.isDate(date, inSameDayAs: Date()) { return "오늘" }
        return date.onlydate()
    }

    // 지출 점 색상 — 일일 예산 대비 강도 (기존 event()와 동일)
    private func expenseDotColor(for date: Date) -> Color {
        guard date >= periodStart && date <= periodEnd else {
            return outOfPeriodDotColor
        }

        let total = expenseTotalsByDay[date.startOfDay] ?? 0

        // 예산이 아직 없으면(온보딩 전 / 동기화 전) 강도를 판단할 기준이 없다.
        // dailyBudget이 0이면 지출이 1원만 있어도 "1.5배 초과"가 되어 모든 날이 최대 강도로 칠해진다.
        guard dailyBudget > 0 else {
            return Color(uiColor: .systemPink).opacity(0.2)
        }

        if total > Int(Double(dailyBudget) * 1.5) {
            return Color(uiColor: .systemPink)
        } else if total > dailyBudget {
            return Color(uiColor: .systemPink).opacity(0.6)
        } else {
            return Color(uiColor: .systemPink).opacity(0.2)
        }
    }
}
