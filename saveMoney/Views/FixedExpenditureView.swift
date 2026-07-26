import SwiftUI
import SwiftData
import UserNotifications

// 고정 지출 관리 화면 (CalendarView에서 fullScreenCover로 표시).
// SwiftData를 직접 사용하고, 항목별 푸시 알림을 externalID 기준으로 등록/해제한다.
struct FixedExpenditureView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var swiftUIDismiss

    @Query(sort: \FixedExpenditureEntity.day)
    private var fixedItems: [FixedExpenditureEntity]

    @Query private var profiles: [ProfileEntity]

    // 입력 상태
    @State private var selectedDay: Int?           // nil이면 미선택 ("언제?" 표시)
    @State private var towhat: String = ""
    @State private var howText: String = ""
    @State private var showDayPicker: Bool = false
    // 삭제 대상은 @Model이 아니라 externalID로 들고 있는다 — 알럿이 떠 있는 동안 다른 기기의
    // 삭제가 동기화되면 붙들고 있던 인스턴스가 무효화되어 속성 접근만으로 크래시한다
    // (지출/수입 화면의 deleteFin과 같은 패턴)
    @State private var deleteTarget: String?
    @State private var addFailureMessage: String?   // 저장 실패/잘못된 금액을 알림 (입력은 보존)
    @State private var notificationAuthorized = false   // 권한 확정 후에만 알림 재등록
    @FocusState private var focused: Field?

    enum Field: Hashable { case towhat, how }

    private let notificationCenter = UNUserNotificationCenter.current()

    private var nickName: String {
        (profiles.canonical?.asProfile ?? Profile()).nickName
    }

    private var totalCost: Int {
        fixedItems.reduce(0) { $0 + $1.how }
    }

    // 날짜별 그룹핑 (day 오름차순)
    private var groupedByDay: [(day: Int, items: [FixedExpenditureEntity])] {
        Dictionary(grouping: fixedItems, by: \.day)
            .sorted { $0.key < $1.key }
            .map { (day: $0.key, items: $0.value) }
    }

    private var trimmedTowhat: String {
        towhat.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // 0원은 저장 직전 addItem에서도 막지만, 여기서 걸러야 버튼이 켜졌는데 탭하면 알럿만 뜨는
    // 어긋남이 생기지 않는다
    private var canAdd: Bool {
        selectedDay != nil && !trimmedTowhat.isEmpty && howText.toInt() > 0
    }

    var body: some View {
        ZStack {
            Color(.background)
                .ignoresSafeArea()
                .onTapGesture { focused = nil }

            VStack(spacing: 0) {
                navBar

                inputRow
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                itemList
            }
        }
        .deleteConfirmationAlert(item: $deleteTarget, message: "해당 고정 지출 내역을 삭제해요.") {
            deleteItem($0)
        }
        .alert("알림", isPresented: Binding(
            get: { addFailureMessage != nil },
            set: { if !$0 { addFailureMessage = nil } }
        )) {
            Button("확인") { addFailureMessage = nil }
        } message: {
            Text(addFailureMessage ?? "")
        }
        .sheet(isPresented: $showDayPicker) {
            // 초기값만 넘기고 확정("설정") 시에만 부모 상태 갱신 — 시트를 스와이프로 닫으면
            // 휠 값이 버려진다 (과거 @Binding 공유로 표시값과 저장값이 어긋나던 버그 수정)
            DaySelectorSheet(initialDay: selectedDay ?? 1) { day in
                selectedDay = day
                showDayPicker = false
            }
            .presentationDetents([.fraction(0.4)])
        }
        .onAppear {
            // 권한 요청은 비동기다. 응답을 기다리지 않고 재등록하면, 권한 미결정 상태의 첫 진입에서
            // removeAll로 기존 알림을 지운 뒤 재등록이 권한 거부로 실패해 알림만 전부 사라진다.
            // 콜백에서는 플래그만 올리고 실제 재등록은 뷰 갱신 경로에서 한다 —
            // escaping 클로저가 캡처한 @Query 스냅샷이 아니라 최신 fixedItems를 쓰기 위함.
            requestNotificationAuthorization { notificationAuthorized = true }
        }
        .onChange(of: notificationAuthorized) { _, authorized in
            if authorized { rescheduleAllNotifications() }
        }
        // CloudKit 동기화가 늦어 화면 진입 시점에 목록이 비어 있으면 아래 가드에 걸려 알림이
        // 하나도 등록되지 않는다. 목록이 채워지는 순간 다시 등록한다.
        .onChange(of: fixedItems.count) { _, _ in
            if notificationAuthorized { rescheduleAllNotifications() }
        }
    }

    // MARK: - 네비게이션 바 (xmark | 총액 | plus)

    private var navBar: some View {
        HStack {
            Button {
                performDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(.customLabel))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button {
                addItem()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color(.fixed))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canAdd)
            .opacity(canAdd ? 1 : 0.4)
        }
        .frame(height: 44)
        .overlay {
            Text("📌 \(totalCost.toDecimal())원")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(.customLabel))
        }
        .padding(.horizontal, 8)
    }

    // MARK: - 입력 줄 (언제? | 어디서? | 얼마?)

    private var inputRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // 언제? — 탭하면 일(day) wheel picker sheet
                Button {
                    focused = nil
                    showDayPicker = true
                } label: {
                    Text(selectedDay.map { "\($0)일" } ?? "언제?")
                        .font(.pretendard(.bold, size: 14))
                        .foregroundStyle(selectedDay == nil
                                         ? Color(uiColor: .placeholderText)
                                         : Color(.customLabel))
                        .frame(maxWidth: .infinity)
                }
                .frame(width: 70)

                TextField("어디서?", text: $towhat)
                    .font(.pretendard(.semiBold, size: 14))
                    .foregroundStyle(Color(.customLabel))
                    .multilineTextAlignment(.center)
                    .focused($focused, equals: .towhat)
                    .submitLabel(.next)
                    .onSubmit { focused = .how }
                    .onChange(of: towhat) { _, new in
                        if new.count > 15 { towhat = String(new.prefix(15)) }
                    }

                TextField("얼마?", text: $howText)
                    .font(.pretendard(.semiBold, size: 14))
                    .foregroundStyle(Color(.customLabel))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .focused($focused, equals: .how)
                    .onChange(of: howText) { _, new in
                        // 실시간 반점 + 11자(반점 포함) 제한
                        let formatted = new.currencyInputFormatted(limit: .formattedChars(11))
                        if formatted != new { howText = formatted }
                    }
            }
            .frame(height: 50)

            // 하단 줄 (fixedColor 1.5pt)
            Rectangle()
                .fill(Color(.fixed))
                .frame(height: 1.5)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("이전") { focused = .towhat }
                    .disabled(focused == .towhat)
                Spacer()
                Button("다음") { focused = .how }
                    .disabled(focused == .how)
            }
        }
    }

    // MARK: - 날짜별 목록

    private var itemList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedByDay, id: \.day) { group in
                    // 섹션 헤더 "n일" (정수 보간 Text는 LocalizedStringKey 콤마 함정 예방 위해 verbatim)
                    Text(verbatim: "\(group.day)일")
                        .font(.system(size: 12, weight: .bold))
                        .opacity(0.4)
                        .frame(height: 36)
                        .padding(.leading, 24)

                    ForEach(group.items) { item in
                        itemRow(item)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func itemRow(_ item: FixedExpenditureEntity) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(item.towhat)
                    .font(.pretendard(.semiBold, size: 14))
                    .foregroundStyle(Color(.customLabel))
                    .lineLimit(1)

                Spacer()

                Text("\(item.how.toDecimal()) 원")
                    .font(.pretendard(.semiBold, size: 16))
                    .foregroundStyle(Color(.customLabel))

                Button {
                    deleteTarget = item.externalID
                } label: {
                    Image(systemName: "trash.square")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(.fixed))
                        .frame(width: 50, height: 50)
                }
            }
            .frame(height: 36)

            HairlineDivider()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 데이터 조작

    private func addItem() {
        guard let day = selectedDay, canAdd else { return }

        // 금액이 0이면 저장하지 않는다 — 과거엔 파싱 실패("₩123", 전각 숫자 등)가 toInt()의
        // 0 폴백을 타고 0원 항목 + "0원이 나가요" 알림으로 남았다.
        // (입력 포맷터가 숫자만 남기도록 고쳐졌지만, 저장 직전에도 한 번 더 막는다)
        let amount = howText.toInt()
        guard amount > 0 else {
            addFailureMessage = "금액을 다시 확인해주세요."
            return
        }

        let entity = FixedExpenditureEntity(
            day: day,
            towhat: trimmedTowhat,
            how: amount
        )
        modelContext.insert(entity)

        // 위젯이 FixedExpenditureEntity를 표시하지 않으므로 타임라인 리로드는 생략 (일반 save).
        // 저장 실패 시 입력을 비우면 사용자가 처음부터 다시 쳐야 하므로, 되돌리고 알린다.
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(entity)
            PersistenceController.logger.error("고정 지출 저장 실패: \(String(describing: error), privacy: .public)")
            addFailureMessage = "저장에 실패했어요. 잠시 후 다시 시도해주세요."
            return
        }

        // 푸시 알림 등록 (externalID를 식별자로 사용)
        notificationCenter.addNotificationRequest(
            to: nickName,
            by: FixedExpenditureItem(id: entity.externalID, day: entity.day, towhat: entity.towhat, how: entity.how)
        )

        // 입력 초기화
        selectedDay = nil
        towhat = ""
        howText = ""
        focused = nil

    }

    private func deleteItem(_ externalID: String) {
        // 알럿이 떠 있는 사이 다른 기기의 삭제가 동기화됐을 수 있으므로 확인 시점에 다시 찾는다
        let descriptor = FetchDescriptor<FixedExpenditureEntity>(
            predicate: #Predicate { $0.externalID == externalID }
        )
        guard let item = (try? modelContext.fetch(descriptor))?.first, !item.isDeleted else {
            // 이미 원격에서 지워진 항목이어도 이 기기의 반복 알림은 남아 있을 수 있다 →
            // 그냥 돌아가면 매월 유령 알림이 발화하므로 해제만이라도 수행한다
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [externalID])
            return
        }

        // 알림을 먼저 해제한다. 저장 실패 시 삭제가 pending으로 남아 autosave가 뒤늦게 커밋할 수
        // 있는데, 그때는 이 함수가 끝난 뒤라 해제할 기회가 없어 매월 유령 알림이 남는다.
        // 반대로 삭제가 끝내 취소되면 화면 재진입 시 rescheduleAllNotifications가 다시 등록한다.
        //
        // modelContext.rollback()은 쓰지 않는다 — mainContext는 앱 전역 공유라
        // 다른 화면에서 입력 중이던 미저장 변경까지 통째로 폐기된다.
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [externalID])
        modelContext.delete(item)

        // 위젯이 FixedExpenditureEntity를 표시하지 않으므로 타임라인 리로드는 생략 (일반 save)
        do {
            try modelContext.save()
        } catch {
            PersistenceController.logger.error("고정 지출 삭제 저장 실패: \(String(describing: error), privacy: .public)")
            addFailureMessage = "삭제에 실패했어요. 잠시 후 다시 시도해주세요."
        }
    }

    // MARK: - 알림

    // 권한이 확정된 뒤에만 onGranted를 부른다 (거부/오류면 호출하지 않아 기존 알림을 건드리지 않는다)
    private func requestNotificationAuthorization(onGranted: @escaping () -> Void) {
        #if DEBUG
        // 스크린샷 자동화(SHOW_SCREEN) 시 시스템 알림 권한 팝업이 화면을 가리지 않도록 스킵
        if ProcessInfo.processInfo.environment[LaunchEnvKeys.showScreen] != nil {
            onGranted()
            return
        }
        #endif
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print(error)
            }
            guard granted else { return }
            DispatchQueue.main.async { onGranted() }
        }
    }

    // 화면 진입시 등록된 고정 지출 전체 알림 재등록 (기존 fixedExpenditureVC.viewDidLoad와 동일)
    private func rescheduleAllNotifications() {
        // 목록이 비어 있으면 아무것도 하지 않는다.
        // CloudKit 동기화 전에는 @Query가 잠시 비어 보일 수 있는데, 그 상태에서 removeAll을 하면
        // 정상 등록돼 있던 알림이 전부 사라지고 재등록되지 않는다.
        // (원격에서 "마지막" 항목이 지워진 경우의 알림 잔존은 감수한다 — 항목이 하나라도 남아
        //  있으면 아래 removeAll + 재등록 과정에서 정리된다)
        guard !fixedItems.isEmpty else { return }
        notificationCenter.removeAllPendingNotificationRequests()
        for item in fixedItems {
            notificationCenter.addNotificationRequest(
                to: nickName,
                by: FixedExpenditureItem(id: item.externalID, day: item.day, towhat: item.towhat, how: item.how)
            )
        }
    }

    // MARK: - Dismiss

    private func performDismiss() {
        // CalendarView가 fullScreenCover로 띄우므로 SwiftUI dismiss로 충분
        swiftUIDismiss()
    }
}

// MARK: - 일(day) 선택 시트

struct DaySelectorSheet: View {
    @State private var day: Int
    let onConfirm: (Int) -> Void

    init(initialDay: Int, onConfirm: @escaping (Int) -> Void) {
        _day = State(initialValue: initialDay)
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            Picker("일", selection: $day) {
                ForEach(1...31, id: \.self) { day in
                    Text(verbatim: "\(day)일").tag(day)
                }
            }
            .pickerStyle(.wheel)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("설정") {
                        onConfirm(day)
                    }
                }
            }
        }
    }
}

#Preview {
    FixedExpenditureView()
        .modelContainer(PreviewSampleData.container)
}
