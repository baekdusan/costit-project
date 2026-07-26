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
    // 삭제 대상은 @Model이 아니라 externalID로 들고 있는다 (원격 삭제 동기화 시 무효화 크래시 회피)
    @State private var deleteTarget: String?
    @State private var showStorageWarning = false
    @State private var didWarnStorage = false          // onAppear는 cover를 닫을 때마다 다시 돌아 경고가 반복된다
    @State private var showProfileSaveFailure = false   // 알럿 표시용 (닫으면 false로 돌아감)
    // 저장 실패 "이력" — 알럿을 닫아도 유지된다. 이걸 따로 두지 않으면 알럿을 닫는 순간
    // 가드가 풀려, 아직 저장되지 않은(pending) 프로필을 보고 firstOpen을 켜버려
    // 재입력 기회를 남기려던 의도가 무력화된다.
    @State private var didFailProfileSave = false
    @State private var deleteFailureMessage: String?

    // MARK: - 파생 데이터

    private var userProfile: Profile {
        profiles.canonical?.asProfile ?? Profile()
    }

    private var salaryData: SalaryDate {
        // 프로필이 있으면 급여일로 "지금 맞는 기간"을 계산해 쓴다 — 위젯(widget.swift)과 동일한 규칙.
        //
        // 저장된 SalaryPeriodEntity를 우선하면 두 가지가 어긋난다:
        //  (1) 앱을 켜지 않은 채 급여일 자정을 넘기면 위젯은 새 기간, 앱은 rollover 전이라 옛 기간을
        //      표시해 같은 시점에 서로 다른 잔액이 보인다.
        //  (2) CloudKit 중복으로 프로필과 기간 엔티티가 각각 다른 행에서 선택되면,
        //      화면의 급여일과 실제 필터 기간이 서로 다른 세대의 값이 된다.
        // 저장 엔티티는 프로필을 아직 모르는 경우의 폴백으로만 쓰고,
        // 값 자체의 갱신은 rolloverSalaryPeriodIfNeeded가 계속 담당한다.
        if let profile = profiles.canonical {
            return SalaryDate.period(forSalaryDay: profile.period)
        }
        return salaryPeriods.canonical?.asSalaryDate ?? SalaryDate()
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
        // end는 기간 마지막 날 23:59:59(정각)라 `<= end`로 비교하면 소수초를 가진 레코드가
        // 다음 기간 시작(00:00)보다도 이르러 어느 기간에도 속하지 않는다 → 반열린 구간으로 비교
        let upperBound = end.addingTimeInterval(1)
        return expenses.filter { $0.when >= start && $0.when < upperBound }
    }

    // 날짜별 섹션 (최신 날짜 먼저)
    private var sections: [(date: Date, items: [FinDataEntity])] {
        Dictionary(grouping: filteredExpenses) { $0.when.startOfDay }
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, items: $0.value) }
    }

    // 사용자가 실제로 입력한 프로필이 있는가 (마이그레이션이 만든 기본값 프로필과 구분)
    private var hasUserEnteredProfile: Bool {
        guard let profile = profiles.canonical else { return false }
        return profile.outLay > 0 || profile.nickName != Profile().nickName
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
            .alert("삭제 실패", isPresented: Binding(
                get: { deleteFailureMessage != nil },
                set: { if !$0 { deleteFailureMessage = nil } }
            )) {
                Button("확인") { deleteFailureMessage = nil }
            } message: {
                Text(deleteFailureMessage ?? "")
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
                if PersistenceController.isEphemeralFallback && !didWarnStorage {
                    didWarnStorage = true
                    showStorageWarning = true
                }
            }
            .onChange(of: hasUserEnteredProfile) { _, entered in
                // 온보딩 중에 CloudKit이 기존 프로필을 뒤늦게 내려주는 경우(기기 교체·재설치).
                // 그대로 두면 사용자가 다시 입력한 값이 기존 프로필과 정산 기간을 덮어써
                // 급여일이 바뀌고 이전 기간 지출이 화면에서 사라진다 → 온보딩을 접는다.
                guard entered, profileRoute == .onboarding, !didFailProfileSave else { return }
                profileRoute = nil
                markOnboardingCompleted()
                rolloverSalaryPeriodIfNeeded()
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
                        deleteTarget = item.externalID
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

    private func deleteExpense(_ externalID: String) {
        // 저장에 실패하면 화면에서만 사라지고 다음 실행에 되살아난다 → 사실을 알린다.
        // 이 함수는 삭제 확인 알럿의 "확인" 액션에서 호출되므로, 그 알럿이 닫히는 도중에
        // 곧바로 다음 알럿을 띄우면 표시 요청이 통째로 무시된다 → 닫힌 뒤로 미룬다.
        if !PersistenceController.deleteFin(externalID: externalID, in: modelContext) {
            // 이전 표시 요청이 무시돼 값이 non-nil로 굳어 있으면, 같은 문자열을 다시 넣어도
            // isPresented 전이가 없어 알럿이 영영 뜨지 않는다 → 먼저 비운 뒤 다시 채운다
            deleteFailureMessage = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                deleteFailureMessage = "삭제를 저장하지 못했어요. 잠시 후 다시 시도해주세요."
            }
        }
    }

    // firstOpen 플래그 기록 공통 경로.
    // in-memory 폴백 실행에서는 기록하지 않는다 — 플래그는 UserDefaults(영속)에 남는데
    // 프로필은 컨테이너와 함께 사라지므로, 다음 정상 실행에서 프로필이 없는데도 온보딩이
    // 뜨지 않아 예산 0원·닉네임 "User"로 굳는다.
    private func markOnboardingCompleted() {
        guard !PersistenceController.isEphemeralFallback else { return }
        UserDefaults.standard.setValue(true, forKey: AppKeys.firstOpen)
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

        // 방금 저장에 실패한 프로필은 컨텍스트에 pending으로만 남아 있다. 그걸 "입력 완료"로 보고
        // 플래그를 켜면 handleProfileInput이 일부러 미룬 기록을 여기서 대신 해버려,
        // 저장이 끝내 실패했을 때 재입력 기회가 사라진다.
        guard !didFailProfileSave else { return }

        // "프로필 엔티티가 존재하는가"가 아니라 "사용자가 실제로 입력했는가"로 판정한다.
        // 구버전 마이그레이션이 기본값 프로필(닉네임 "User", 예산 0원)을 만들어둔 기기가 있어서,
        // 단순 존재 여부로 보면 그 사용자는 온보딩을 영영 받지 못하고 예산 0원으로 굳는다.
        if hasUserEnteredProfile {
            markOnboardingCompleted()
            return
        }

        DispatchQueue.main.async {
            profileRoute = .onboarding
        }
    }

    // 프로필 입력 처리 (온보딩 / 프로필 수정 공통 — 기존 handleProfileInput과 동일)
    private func handleProfileInput(nickname: String, outLay: Int, period: String) {
        applyProfileToAllEntities(nickname: nickname, outLay: outLay, period: period)

        // 급여일 기준으로 정산 기간 재설정 (같은 이유로 사본 전체를 갱신)
        applyPeriodToAllEntities(SalaryDate.period(forSalaryDay: period), save: false)

        displayRange = .salaryPeriod

        // 플래그는 저장이 성공한 뒤에 기록한다 — 먼저 켜두면 저장이 실패했을 때
        // 다음 실행에서 온보딩을 건너뛰어 사용자가 입력한 프로필이 사라진 채로 시작한다
        if PersistenceController.saveAndRefreshWidgets(modelContext) {
            didFailProfileSave = false
            markOnboardingCompleted()
        } else {
            // 화면은 이미 닫히는 중이므로 최소한 사실은 알린다 (조용한 유실 방지)
            didFailProfileSave = true
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
        // 프로필이 아직 없으면(온보딩 전 / CloudKit 동기화 대기) 급여일을 알 수 없으므로
        // 기간을 재계산하지 않는다 — 기본값 "1일"로 덮어쓰면 기존 사용자의 기간이 달력월로 바뀐다.
        // 다만 구버전이 저장한 "start가 말일 23:59:59" 같은 값은 급여일을 몰라도 틀린 게 확실하므로
        // 그 날 00:00으로 내려 급여일 당일 지출이 필터에서 빠지는 것만은 막는다(정상 값은 건드리지 않음).
        guard profiles.canonical != nil else {
            guard let entity = salaryPeriods.canonical else { return }

            // 프로필이 없다고 어긋난 기간을 그대로 두면 정산 기간이 영구 동결되어,
            // 그 뒤에 저장한 지출이 메인 화면과 위젯 양쪽에서 사라진다(캘린더에만 보임).
            // 급여일을 모르므로 저장된 start의 '일'을 급여일로 간주해 "지금 맞는 기간"을 구한다 —
            // 그 값 자체가 과거에 급여일로 계산된 결과다.
            //
            // 만료(과거)뿐 아니라 미래로 어긋난 경우도 교정해야 한다. 시계가 앞선 기기(또는 그 기기의
            // CloudKit 동기화)가 미래 기간을 써두면, 만료 조건에 걸리지 않아 영원히 그 상태로 남고
            // 그동안 모든 지출이 기간 밖으로 밀려난다.
            let day = Calendar(identifier: .gregorian).component(.day, from: entity.startDate.startOfDay)
            let expectedWithoutProfile = SalaryDate.period(forSalaryDay: SalaryDay.day(day))
            guard entity.startDate != expectedWithoutProfile.startDate
                    || entity.endDate != expectedWithoutProfile.endDate else { return }

            applyPeriodToAllEntities(expectedWithoutProfile)
            return
        }

        let expected = SalaryDate.period(forSalaryDay: userProfile.period)

        // 엔티티가 없어도 여기서 만들지 않는다. CloudKit이 프로필만 먼저 내려준 순간에 생성하면
        // 뒤늦게 도착하는 기존 SalaryPeriodEntity와 중복 행이 되고, 무정렬 선택 문제가 다시 생긴다.
        // 엔티티가 없는 동안에는 salaryData 폴백이 위젯과 같은 계산식을 쓰므로 표시는 정확하고,
        // 실제 생성은 온보딩/프로필 수정(handleProfileInput)이 담당한다.
        guard let entity = salaryPeriods.canonical else { return }

        guard entity.startDate != expected.startDate || entity.endDate != expected.endDate else { return }

        applyPeriodToAllEntities(expected)
    }

    // MARK: - 싱글턴 엔티티 쓰기 (반드시 이 두 함수를 거칠 것)
    //
    // CloudKit은 @Attribute(.unique)를 지원하지 않아 프로필·정산기간 사본이 여러 벌 생길 수 있다.
    // 삭제로 정리하지 않고(삭제는 되돌릴 수 없다) "쓸 때 사본 전체를 같은 값으로 맞추는" 방식을 쓴다.
    // 그래야 canonical이 어느 사본을 고르든, 앱과 위젯이 각각 다른 사본을 읽든 값이 같다.
    //
    // ⚠️ 사본 하나만 고치면(profiles.first?.outLay = …) 즉시 이 불변식이 깨져
    //    사용자가 방금 입력한 값이 되돌아간다. 프로필·기간을 바꾸는 코드는 전부 여기로 모은다.

    private func applyProfileToAllEntities(nickname: String, outLay: Int, period: String) {
        guard !profiles.isEmpty else {
            modelContext.insert(ProfileEntity(nickName: nickname, outLay: outLay, period: period))
            return
        }
        for entity in profiles {
            entity.nickName = nickname
            entity.outLay = outLay
            entity.period = period
        }
    }

    // save: false면 호출부가 저장을 책임진다(여러 엔티티를 한 번에 바꾸고 한 번만 저장하는 경우)
    private func applyPeriodToAllEntities(_ period: SalaryDate, save: Bool = true) {
        if salaryPeriods.isEmpty {
            modelContext.insert(SalaryPeriodEntity(startDate: period.startDate, endDate: period.endDate))
        } else {
            for entity in salaryPeriods {
                entity.startDate = period.startDate
                entity.endDate = period.endDate
            }
        }
        if save {
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
