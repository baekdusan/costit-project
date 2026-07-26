import SwiftUI
import SwiftData

// mainVC를 SwiftUI로 옮긴 버전 — 앱의 루트 화면 (SceneDelegate에서 직접 띄움).
// SwiftData만 사용한다. UserDefaults에는 더 이상 데이터를 기록하지 않으며
// "firstOpen" 플래그만 유지한다.
struct MainView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var showStorageWarning = false

    // MARK: - 파생 데이터

    private var userProfile: Profile {
        profiles.first?.asProfile ?? Profile()
    }

    private var salaryData: SalaryDate {
        salaryPeriods.first?.asSalaryDate ?? SalaryDate()
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
            return salaryData.startDate.toString() + " ~ " + salaryData.endDate.toString()
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
                        BalanceHeader(balance: balanceText, condition: balanceConditionText)

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
                            CircleActionButton(systemName: "arrow.left.arrow.right", background: Color(.header)) {
                                presentRevenue()
                            }
                            .padding(.leading, 30)

                            Spacer()

                            CircleActionButton(systemName: "highlighter", background: Color(.header)) {
                                presentAddFin(source: .expense, mode: .new)
                            }
                            .padding(.trailing, 30)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .background {
                MainBackground()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showProfileEditor = true
                    } label: {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color(.customLabel))
                    }
                }

                ToolbarItem(placement: .principal) {
                    // 기간 타이틀 — 탭하면 년/월 선택
                    Button {
                        showMonthSelector = true
                    } label: {
                        Text(navTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(.customLabel))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(Color(.customLabel))
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
            .deleteConfirmationAlert(item: $deleteTarget, message: "해당 지출 내역을 삭제해요.") {
                deleteExpense($0)
            }
            .alert("저장할 수 없는 상태예요", isPresented: $showStorageWarning) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("기기 저장소를 열지 못했어요. 지금 입력하는 내역은 앱을 종료하면 사라집니다.\n저장 공간을 확보하거나 기기를 재시작한 뒤 다시 실행해주세요. 기존에 저장된 내역은 그대로 남아 있어요.")
            }
            .onAppear {
                rolloverSalaryPeriodIfNeeded()
                presentOnboardingIfNeeded()
                // 스토어를 못 열어 in-memory로 폴백한 실행이면 즉시 알린다 (입력 유실 예방)
                if PersistenceController.isEphemeralFallback {
                    showStorageWarning = true
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                // 앱이 백그라운드에 있다가 정산 기간이 끝난 뒤 foreground로 복귀할 때도
                // 자동 reset (onAppear는 cold start에만 불려 복귀 시 갱신이 안 됨)
                if newPhase == .active {
                    rolloverSalaryPeriodIfNeeded()
                }
            }
        }
    }

    // MARK: - 섹션 헤더 / 카드

    private func sectionHeader(_ section: (date: Date, items: [FinDataEntity])) -> some View {
        let total = section.items.reduce(0) { $0 + $1.how }

        return VStack(alignment: .leading, spacing: 2) {
            Text(section.date.onlydate() + "일")
                .font(.pretendard(.semiBold, size: 20))
            Text(total.toDecimal() + "원")
                .font(.pretendard(.medium, size: 14))
                .opacity(0.2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 92)
        .padding(.horizontal, 25)
    }

    private func expenseCard(_ item: FinDataEntity, size: CGFloat) -> some View {
        ZStack {
            Color(.memoPaper)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(item.when.toString())
                        .font(.pretendard(.regular, size: 12))
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
                    .font(.pretendard(.medium, size: 16))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 12)

                Spacer()

                Text(item.how == 0 ? "무료" : "- " + item.how.toDecimal())
                    .font(.pretendard(.bold, size: 18))
                    .opacity(0.84)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .frame(width: size, height: size)
        .paperShadow(y: 6)
        .onLongPressGesture {
            presentAddFin(source: .expense, mode: .edit(.init(item)))
        }
    }

    // MARK: - 화면 전환 (AddFinView / RevenueView는 투명 배경/즉시 전환 위해 UIKit present)
    // AddFinView는 공용 presentAddFin(source:mode:) 경로 사용 (UIKitPresentation.swift)

    private func presentRevenue() {
        let view = RevenueView(start: salaryData.startDate, end: salaryData.endDate)
            .modelContainer(PersistenceController.shared)
            .dynamicTypeSize(.large)
        let host = UIHostingController(rootView: view)
        host.modalPresentationStyle = .fullScreen
        UIApplication.shared.appRootViewController?.present(host, animated: false)
    }

    // MARK: - 데이터 조작

    private func deleteExpense(_ item: FinDataEntity) {
        PersistenceController.delete(item, in: modelContext)
    }

    // 첫 실행 감지 → 온보딩
    // (NavigationStack 설치가 끝나기 전에 isPresented를 켜면 push가 무시될 수 있어 한 틱 지연)
    //
    // 로컬 플래그만 보고 판단하면 안 된다: 기기를 바꾸거나 앱을 재설치하면 UserDefaults는
    // 비어 있지만 프로필은 CloudKit에 남아 있다. 그 상태로 온보딩을 강제하면 사용자가 다시
    // 입력한 값이 기존 프로필과 정산 기간을 덮어써(급여일이 바뀌면 이전 기간 지출이 화면에서
    // 사라진다), 동기화 전에 완료하면 프로필 엔티티가 중복 생성된다.
    private func presentOnboardingIfNeeded() {
        guard UserDefaults.standard.bool(forKey: AppKeys.firstOpen) == false else { return }

        // 이미 프로필이 있으면(= 기존 사용자) 온보딩 없이 플래그만 맞춰준다
        if profiles.isEmpty == false {
            UserDefaults.standard.setValue(true, forKey: AppKeys.firstOpen)
            return
        }

        DispatchQueue.main.async {
            showOnboarding = true
        }
    }

    // 프로필 입력 처리 (온보딩 / 프로필 수정 공통 — 기존 handleProfileInput과 동일)
    private func handleProfileInput(nickname: String, outLay: Int, period: String) {
        // 프로필 upsert
        let profileEntity = profiles.first ?? {
            let entity = ProfileEntity()
            modelContext.insert(entity)
            return entity
        }()
        profileEntity.nickName = nickname
        profileEntity.outLay = outLay
        profileEntity.period = period

        // 급여일 기준으로 정산 기간 재설정
        let newPeriod = SalaryDate.period(forSalaryDay: period)
        let periodEntity = salaryPeriods.first ?? {
            let entity = SalaryPeriodEntity()
            modelContext.insert(entity)
            return entity
        }()
        periodEntity.startDate = newPeriod.startDate
        periodEntity.endDate = newPeriod.endDate

        displayRange = .salaryPeriod

        // 플래그는 저장이 성공한 뒤에 기록한다 — 먼저 켜두면 저장이 실패했을 때
        // 다음 실행에서 온보딩을 건너뛰어 사용자가 입력한 프로필이 사라진 채로 시작한다
        if PersistenceController.saveAndRefreshWidgets(modelContext) {
            UserDefaults.standard.setValue(true, forKey: AppKeys.firstOpen)
        }
    }

    // 오늘이 정산 기간을 넘어가면 프로필 급여일에 맞춰 기간 갱신 (기존 viewDidLoad 로직)
    private func rolloverSalaryPeriodIfNeeded() {
        guard let entity = salaryPeriods.first else { return }
        var changed = false

        // 구버전 '마지막 날' 로직이 저장한 start(말일 23:59:59)를 즉시 교정 — 정상 기간의
        // start는 항상 그 날 00:00이므로 정당한 값은 건드리지 않음 (endDate 불변이라 rollover 무영향)
        if entity.startDate != entity.startDate.startOfDay {
            entity.startDate = entity.startDate.startOfDay
            changed = true
        }

        if Date() > entity.endDate {
            let newPeriod = SalaryDate.period(forSalaryDay: userProfile.period)
            entity.startDate = newPeriod.startDate
            entity.endDate = newPeriod.endDate
            changed = true
        }

        if changed {
            PersistenceController.saveAndRefreshWidgets(modelContext)   // 기간이 바뀌었으니 위젯도 갱신
        }
    }
}

// MARK: - 서브뷰

// 잔액 헤더 (우측 정렬 잔액 + 조건 문구)
private struct BalanceHeader: View {
    let balance: String
    let condition: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(balance)
                .font(.pretendard(.semiBold, size: 32))
                .opacity(0.78)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(condition)
                .font(.pretendard(.medium, size: 16))
                .opacity(0.48)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 2)
        .padding(.trailing, 18)
        .padding(.leading, 18)
    }
}

// 배경: backgroundColor + 상단 그라데이션 (기존 topView)
private struct MainBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Color(.background)
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color(.topView),
                        Color(.background).opacity(0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 175)
                Spacer(minLength: 0)
            }
        }
        .ignoresSafeArea()
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
