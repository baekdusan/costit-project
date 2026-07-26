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

    // 온보딩과 프로필 편집은 같은 FirstOpenView를 다른 모드로 띄운다.
    // 각각 별도의 navigationDestination(isPresented:)를 달면 같은 컨테이너에 두 개가 붙어
    // 뒤쪽이 앞쪽을 덮어써 온보딩 push가 발화하지 않는다 → 단일 목적지로 통합한다.
    enum ProfileRoute: Hashable {
        case onboarding     // 첫 실행 (빈 입력 + 뒤로가기 없음)
        case editor         // 프로필 수정 (기존 값 채움)
    }

    @State private var displayRange: DisplayRange = .salaryPeriod
    @State private var showMonthSelector = false
    @State private var showCalendar = false
    @State private var profileRoute: ProfileRoute?
    @State private var deleteTarget: FinDataEntity?
    @State private var showStorageWarning = false
    @State private var showProfileSaveFailure = false

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
                        profileRoute = .editor
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
            .navigationDestination(item: $profileRoute) { route in
                switch route {
                case .onboarding:
                    FirstOpenView { nickname, outLay, period in
                        handleProfileInput(nickname: nickname, outLay: outLay, period: period)
                        profileRoute = nil
                    }
                    .navigationBarBackButtonHidden(true)
                case .editor:
                    FirstOpenView(editing: userProfile) { nickname, outLay, period in
                        handleProfileInput(nickname: nickname, outLay: outLay, period: period)
                        profileRoute = nil
                    }
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
            .alert("프로필 저장 실패", isPresented: $showProfileSaveFailure) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("입력한 프로필을 저장하지 못했어요. 사람 아이콘을 눌러 다시 시도해주세요.")
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

        // "프로필 엔티티가 존재하는가"가 아니라 "사용자가 실제로 입력했는가"로 판정한다.
        // 구버전 마이그레이션이 기본값 프로필(닉네임 "User", 예산 0원)을 만들어둔 기기가 있어서,
        // 단순 존재 여부로 보면 그 사용자는 온보딩을 영영 받지 못하고 예산 0원으로 굳는다.
        if let profile = profiles.first,
           profile.outLay > 0 || profile.nickName != Profile().nickName {
            UserDefaults.standard.setValue(true, forKey: AppKeys.firstOpen)
            return
        }

        DispatchQueue.main.async {
            profileRoute = .onboarding
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
        } else {
            // 화면은 이미 닫히는 중이므로 최소한 사실은 알린다 (조용한 유실 방지)
            showProfileSaveFailure = true
        }
    }

    // 저장된 정산 기간을 프로필 급여일 기준의 "지금 맞는 기간"과 대조해 어긋나면 교정한다.
    //
    // 과거엔 (a) start가 00:00이 아닐 때와 (b) 기간이 만료됐을 때만 갱신했다. 그러면 구버전 로직이
    // 계산해 이미 저장해둔 잘못된 기간(예: 급여일 30일 → [3/2~3/29])은 만료 전까지 그대로 쓰여,
    // 2/28·3/1 지출이 계속 화면에서 사라진 채로 남았다. 만료되면 다음 기간으로 건너뛰므로
    // 그 지출들은 영영 어떤 기간에도 나타나지 않는다.
    //
    // 이 엔티티는 항상 "급여일로 계산한 현재 기간"만 담는다(사용자가 고른 년/월 범위는 displayRange가
    // 따로 들고 있다). 따라서 계산 결과와 다르면 무조건 저장값이 틀린 것이다.
    private func rolloverSalaryPeriodIfNeeded() {
        // 프로필이 아직 없으면(온보딩 전 / CloudKit 동기화 대기) 급여일을 알 수 없으므로 손대지 않는다 —
        // 기본값 "1일"로 계산해 덮어쓰면 기존 사용자의 기간이 달력월로 바뀐다
        guard let entity = salaryPeriods.first, profiles.first != nil else { return }

        let expected = SalaryDate.period(forSalaryDay: userProfile.period)
        guard entity.startDate != expected.startDate || entity.endDate != expected.endDate else { return }

        entity.startDate = expected.startDate
        entity.endDate = expected.endDate
        PersistenceController.saveAndRefreshWidgets(modelContext)   // 기간이 바뀌었으니 위젯도 갱신
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
