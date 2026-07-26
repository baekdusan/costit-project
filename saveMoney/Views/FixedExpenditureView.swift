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
    @State private var deleteTarget: FixedExpenditureEntity?
    @State private var addFailureMessage: String?   // 저장 실패/잘못된 금액을 알림 (입력은 보존)
    @FocusState private var focused: Field?

    enum Field: Hashable { case towhat, how }

    private let notificationCenter = UNUserNotificationCenter.current()

    private var nickName: String {
        (profiles.first?.asProfile ?? Profile()).nickName
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

    private var canAdd: Bool {
        selectedDay != nil && !trimmedTowhat.isEmpty && !howText.isEmpty
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
            requestNotificationAuthorization()
            rescheduleAllNotifications()
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
                    deleteTarget = item
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

    private func deleteItem(_ item: FixedExpenditureEntity) {
        // 알럿이 떠 있는 사이 다른 기기의 삭제가 동기화됐다면 이미 무효화된 인스턴스다
        guard !item.isDeleted else { return }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [item.externalID])
        modelContext.delete(item)
        // 위젯이 FixedExpenditureEntity를 표시하지 않으므로 타임라인 리로드는 생략 (일반 save)
        try? modelContext.save()
    }

    // MARK: - 알림

    private func requestNotificationAuthorization() {
        #if DEBUG
        // 스크린샷 자동화(SHOW_SCREEN) 시 시스템 알림 권한 팝업이 화면을 가리지 않도록 스킵
        if ProcessInfo.processInfo.environment[LaunchEnvKeys.showScreen] != nil { return }
        #endif
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
                print(error)
            }
        }
    }

    // 화면 진입시 등록된 고정 지출 전체 알림 재등록 (기존 fixedExpenditureVC.viewDidLoad와 동일)
    private func rescheduleAllNotifications() {
        // 목록이 비어 있어도 removeAll을 수행한다 — 다른 기기에서 마지막 항목을 지운 뒤
        // 그 삭제가 동기화된 경우, 빈 목록이라고 일찍 빠져나가면 이 기기의 알림만 계속 발화한다
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
