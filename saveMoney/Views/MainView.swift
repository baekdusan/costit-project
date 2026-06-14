import SwiftUI
import SwiftData
import WidgetKit

// MARK: - 키 윈도우 탐색 (UIKit present/dismiss 공통 헬퍼)
// windows.first는 키보드/권한 다이얼로그 등 시스템 윈도우가 잡힐 수 있으므로
// isKeyWindow 기준으로 앱 윈도우를 찾는다.
extension UIApplication {
    var appKeyWindow: UIWindow? {
        let windows = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first
    }

    var appRootViewController: UIViewController? {
        appKeyWindow?.rootViewController
    }
}

// mainVC를 SwiftUI로 옮긴 버전 — 앱의 루트 화면 (SceneDelegate에서 직접 띄움).
// SwiftData만 사용한다. UserDefaults에는 더 이상 데이터를 기록하지 않으며
// "firstOpen" 플래그만 유지한다.
struct MainView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<FinDataEntity> { $0.isRevenue == false },
           sort: \FinDataEntity.when, order: .reverse)
    private var expenses: [FinDataEntity]

    @Query private var profiles: [ProfileEntity]
    @Query private var salaryPeriods: [SalaryPeriodEntity]

    // 표시 범위: 정산 기간(기본) / 사용자가 고른 년·월
    enum DisplayRange: Equatable {
        case salaryPeriod
        case custom(start: Date, end: Date, label: String)
    }

    @State private var displayRange: DisplayRange = .salaryPeriod
    @State private var showMonthSelector = false
    @State private var showCalendar = false
    @State private var showOnboarding = false
    @State private var showProfileEditor = false
    @State private var deleteTarget: FinDataEntity?

    // MARK: - 파생 데이터

    private var userProfile: profile {
        if let entity = profiles.first {
            return profile(nickName: entity.nickName, outLay: entity.outLay, period: entity.period)
        }
        return profile()
    }

    private var salaryData: salaryDate {
        if let entity = salaryPeriods.first {
            return salaryDate(startDate: entity.startDate, endDate: entity.endDate)
        }
        return salaryDate()
    }

    private var currentRange: (start: Date, end: Date) {
        switch displayRange {
        case .salaryPeriod:
            return (salaryData.startDate, salaryData.endDate)
        case .custom(let start, let end, _):
            return (start, end)
        }
    }

    private var filteredExpenses: [FinDataEntity] {
        let (start, end) = currentRange
        return expenses.filter { $0.when >= start && $0.when <= end }
    }

    // 날짜별 섹션 (최신 날짜 먼저)
    private var sections: [(date: Date, items: [FinDataEntity])] {
        Dictionary(grouping: filteredExpenses) { $0.when.startOfDay }
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, items: $0.value) }
    }

    private var rangeTotal: Int {
        filteredExpenses.reduce(0) { $0 + $1.how }
    }

    private var balanceText: String {
        switch displayRange {
        case .salaryPeriod:
            return (userProfile.outLay - rangeTotal).toDecimal() + " 원"
        case .custom:
            return rangeTotal.toDecimal() + " 원"
        }
    }

    private var balanceConditionText: String {
        switch displayRange {
        case .salaryPeriod:
            return "/ \(userProfile.outLay.toDecimal()) 원"
        case .custom:
            return "이만큼 사용했어요"
        }
    }

    private var navTitle: String {
        switch displayRange {
        case .salaryPeriod:
            return salaryData.startDate.toString(false) + " ~ " + salaryData.endDate.toString(false)
        case .custom(_, _, let label):
            return label
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                // 초기 레이아웃 패스에서 width가 0이면 음수가 되어 "Invalid frame dimension" 경고 발생 → 0으로 클램프
                let cardSize = max(0, (proxy.size.width - 48) * 0.5)

                ZStack {
                    VStack(spacing: 0) {
                        // 잔액 헤더
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(balanceText)
                                .font(.custom("PretendardVariable-SemiBold", size: 32))
                                .opacity(0.78)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Text(balanceConditionText)
                                .font(.custom("PretendardVariable-Medium", size: 16))
                                .opacity(0.48)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 2)
                        .padding(.trailing, 18)
                        .padding(.leading, 18)

                        // 지출 메모지 그리드
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(sections, id: \.date) { section in
                                    sectionHeader(section)
                                        .scrollFadeAtTop()
                                    LazyVGrid(
                                        columns: [
                                            GridItem(.fixed(cardSize), spacing: 12),
                                            GridItem(.fixed(cardSize))
                                        ],
                                        spacing: 18
                                    ) {
                                        ForEach(section.items) { item in
                                            expenseCard(item, size: cardSize)
                                                .scrollFadeAtTop()
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 140)
                        }
                        .padding(.top, 18)
                    }

                    // 하단 버튼 두 개 (수입 / 지출 입력)
                    VStack {
                        Spacer()
                        HStack {
                            Button {
                                presentRevenue()
                            } label: {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 20, weight: .semibold))
                                    .frame(width: 60, height: 60)
                                    .background(Color("HeaderColor"))
                                    .foregroundStyle(Color("backgroundColor"))
                                    .clipShape(Circle())
                            }
                            .padding(.leading, 30)

                            Spacer()

                            Button {
                                presentAddFin(mode: .new)
                            } label: {
                                Image(systemName: "highlighter")
                                    .font(.system(size: 20, weight: .semibold))
                                    .frame(width: 60, height: 60)
                                    .background(Color("HeaderColor"))
                                    .foregroundStyle(Color("backgroundColor"))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 30)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .background {
                // 배경: backgroundColor + 상단 그라데이션 (기존 topView)
                ZStack(alignment: .top) {
                    Color("backgroundColor")
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                Color("topViewColor"),
                                Color("backgroundColor").opacity(0)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 175)
                        Spacer(minLength: 0)
                    }
                }
                .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showProfileEditor = true
                    } label: {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color("customLabel"))
                    }
                }

                ToolbarItem(placement: .principal) {
                    // 기간 타이틀 — 탭하면 년/월 선택
                    Button {
                        showMonthSelector = true
                    } label: {
                        Text(navTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color("customLabel"))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(Color("customLabel"))
                    }
                }
            }
            .navigationDestination(isPresented: $showOnboarding) {
                FirstOpenView { nickname, outLay, period in
                    handleProfileInput(nickname: nickname, outLay: outLay, period: period)
                    showOnboarding = false
                }
                .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(isPresented: $showProfileEditor) {
                FirstOpenView(editing: userProfile) { nickname, outLay, period in
                    handleProfileInput(nickname: nickname, outLay: outLay, period: period)
                    showProfileEditor = false
                }
            }
            .fullScreenCover(isPresented: $showCalendar) {
                CalendarView(start: salaryData.startDate, end: salaryData.endDate)
            }
            .sheet(isPresented: $showMonthSelector) {
                MonthSelectorSheet(
                    onSelect: { start, end, label in
                        displayRange = .custom(start: start, end: end, label: label)
                        showMonthSelector = false
                    },
                    onReset: {
                        displayRange = .salaryPeriod
                        showMonthSelector = false
                    }
                )
                .presentationDetents([.fraction(0.4)])
            }
            .alert("삭제", isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            )) {
                Button("취소", role: .cancel) { deleteTarget = nil }
                Button("확인") {
                    if let target = deleteTarget {
                        deleteExpense(target)
                    }
                    deleteTarget = nil
                }
            } message: {
                Text("해당 지출 내역을 삭제해요.")
            }
            .onAppear {
                rolloverSalaryPeriodIfNeeded()

                // 첫 실행 감지 → 온보딩
                // (NavigationStack 설치가 끝나기 전에 isPresented를 켜면 push가 무시될 수 있어 한 틱 지연)
                if UserDefaults.standard.bool(forKey: "firstOpen") == false {
                    DispatchQueue.main.async {
                        showOnboarding = true
                    }
                }
            }
        }
    }

    // MARK: - 섹션 헤더 / 카드

    private func sectionHeader(_ section: (date: Date, items: [FinDataEntity])) -> some View {
        let total = section.items.reduce(0) { $0 + $1.how }

        return VStack(alignment: .leading, spacing: 2) {
            Text(section.date.onlydate() + "일")
                .font(.custom("PretendardVariable-SemiBold", size: 20))
            Text(total.toDecimal() + "원")
                .font(.custom("PretendardVariable-Medium", size: 14))
                .opacity(0.2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 92)
        .padding(.horizontal, 25)
    }

    private func expenseCard(_ item: FinDataEntity, size: CGFloat) -> some View {
        ZStack {
            Color("memoPaperColor")

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(item.when.toString(false))
                        .font(.custom("PretendardVariable-Regular", size: 12))
                        .padding(.top, 8)

                    Spacer()

                    Button {
                        deleteTarget = item
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(uiColor: .systemGray5))
                            .frame(width: 22, height: 22)
                    }
                }

                Text(item.towhat)
                    .font(.custom("PretendardVariable-Medium", size: 16))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 12)

                Spacer()

                Text(item.how == 0 ? "무료" : "- " + item.how.toDecimal())
                    .font(.custom("PretendardVariable-Bold", size: 18))
                    .opacity(0.84)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 6)
        .onLongPressGesture {
            presentAddFin(mode: .edit(item))
        }
    }

    // MARK: - 화면 전환 (AddFinView / RevenueView는 투명 배경 위해 UIKit present)

    private var rootViewController: UIViewController? {
        UIApplication.shared.appRootViewController
    }

    private func presentAddFin(mode: AddFinView.Mode) {
        let view = AddFinView(source: .expense, mode: mode)
            .modelContainer(PersistenceController.shared)
            .dynamicTypeSize(.large)
        let host = UIHostingController(rootView: view)
        host.modalPresentationStyle = .overFullScreen
        host.view.backgroundColor = .clear
        rootViewController?.present(host, animated: false)
    }

    private func presentRevenue() {
        let view = RevenueView(start: salaryData.startDate, end: salaryData.endDate)
            .modelContainer(PersistenceController.shared)
            .dynamicTypeSize(.large)
        let host = UIHostingController(rootView: view)
        host.modalPresentationStyle = .fullScreen
        rootViewController?.present(host, animated: false)
    }

    // MARK: - 데이터 조작

    private func deleteExpense(_ item: FinDataEntity) {
        modelContext.delete(item)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // 프로필 입력 처리 (온보딩 / 프로필 수정 공통 — 기존 handleProfileInput과 동일)
    private func handleProfileInput(nickname: String, outLay: Int, period: String) {
        UserDefaults.standard.setValue(true, forKey: "firstOpen")

        // 프로필 upsert
        let profileEntity: ProfileEntity
        if let existing = profiles.first {
            profileEntity = existing
        } else {
            profileEntity = ProfileEntity()
            modelContext.insert(profileEntity)
        }
        profileEntity.nickName = nickname
        profileEntity.outLay = outLay
        profileEntity.period = period

        // 급여일 기준으로 정산 기간 재설정
        let newPeriod = Self.setSalaryDate(period)
        let periodEntity: SalaryPeriodEntity
        if let existing = salaryPeriods.first {
            periodEntity = existing
        } else {
            periodEntity = SalaryPeriodEntity()
            modelContext.insert(periodEntity)
        }
        periodEntity.startDate = newPeriod.startDate
        periodEntity.endDate = newPeriod.endDate

        try? modelContext.save()
        displayRange = .salaryPeriod
        WidgetCenter.shared.reloadAllTimelines()
    }

    // 오늘이 정산 기간을 넘어가면 프로필 급여일에 맞춰 기간 갱신 (기존 viewDidLoad 로직)
    private func rolloverSalaryPeriodIfNeeded() {
        guard let entity = salaryPeriods.first else { return }
        if Date() > entity.endDate {
            let newPeriod = Self.setSalaryDate(userProfile.period)
            entity.startDate = newPeriod.startDate
            entity.endDate = newPeriod.endDate
            try? modelContext.save()
        }
    }

    // 급여일 문자열("1일", "29일", "마지막 날")로 한 달 정산 기간 계산 (기존 mainVC.setSalaryDate)
    static func setSalaryDate(_ salary: String) -> salaryDate {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko")
        // 디바이스가 비양력 캘린더(불교력 등)여도 양력 기준 일자를 얻도록 고정
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd"
        let today = Int(formatter.string(from: Date())) ?? 1

        if salary == "마지막 날" {
            let endOfMonthDay = Int(formatter.string(from: Date().endOfThisMonth)) ?? 28
            if today == endOfMonthDay {
                return salaryDate(startDate: Date().endOfThisMonth, endDate: Date().yesterdayOfEndOfNextMonth)
            }
            return salaryDate(startDate: Date().endOfLastMonth, endDate: Date().yesterdayOfEndOfThisMonth)
        }

        if salary == "1일" {
            return salaryDate(startDate: Date().startOfThisMonth, endDate: Date().endOfThisMonth)
        }

        // "29일" → 29 추출
        let digits = salary.filter { $0.isNumber }
        let salaryDay = Int(digits) ?? 1

        if today >= salaryDay {
            return salaryDate(startDate: Date().startOfSomeDay(salaryDay), endDate: Date().endOfSomeDay(salaryDay))
        } else {
            return salaryDate(startDate: Date().startOfLastSomeDay(salaryDay), endDate: Date().endOfLastSomeDay(salaryDay))
        }
    }
}

// 스크롤로 상단 경계를 벗어나는 동안 서서히 투명해지는 효과.
// (정적 그라데이션 마스크와 달리 스크롤하지 않은 상태의 콘텐츠에는 영향 없음. 하단 경계는 그대로)
private extension View {
    func scrollFadeAtTop() -> some View {
        scrollTransition(.interactive, axis: .vertical) { content, phase in
            content.opacity(phase.value < 0 ? Double(1 + phase.value) : 1)
        }
    }
}

#Preview {
    MainView()
        .modelContainer(PreviewSampleData.container)
}
