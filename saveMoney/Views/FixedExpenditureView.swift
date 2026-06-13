import SwiftUI
import SwiftData
import UserNotifications

// 고정 지출 관리 화면 — fixedExpenditureVC의 SwiftUI 대체.
// SwiftData를 직접 사용하고, 점진 전환 기간 동안 NotificationCenter("toMainVC")로
// mainVC/calendarVC의 UserDefaults 경로와 동기화를 유지한다.
struct FixedExpenditureView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var swiftUIDismiss

    @Query(sort: \FixedExpenditureEntity.day)
    private var fixedItems: [FixedExpenditureEntity]

    @Query private var profiles: [ProfileEntity]

    // 입력 상태
    @State private var dayText: String = ""        // "n일" — 비어있으면 미선택
    @State private var selectedDay: Int = 1
    @State private var towhat: String = ""
    @State private var howText: String = ""
    @State private var showDayPicker: Bool = false
    @State private var deleteTarget: FixedExpenditureEntity?
    @FocusState private var focused: Field?

    enum Field: Hashable { case towhat, how }

    private let notificationCenter = UNUserNotificationCenter.current()

    private var nickName: String {
        profiles.first?.nickName ?? "User"
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

    private var canAdd: Bool {
        !dayText.isEmpty && !towhat.isEmpty && !howText.isEmpty
    }

    var body: some View {
        ZStack {
            Color("backgroundColor")
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
        .alert("삭제", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("취소", role: .cancel) { deleteTarget = nil }
            Button("확인") {
                if let target = deleteTarget {
                    deleteItem(target)
                }
                deleteTarget = nil
            }
        } message: {
            Text("해당 고정 지출 내역을 삭제해요.")
        }
        .sheet(isPresented: $showDayPicker) {
            DaySelectorSheet(selectedDay: $selectedDay) { day in
                selectedDay = day
                dayText = "\(day)일"
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
                    .foregroundStyle(Color("customLabel"))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button {
                addItem()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color("fixedColor"))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canAdd)
            .opacity(canAdd ? 1 : 0.4)
        }
        .frame(height: 44)
        .overlay {
            Text("📌 \(totalCost.toDecimal())원")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color("customLabel"))
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
                    if dayText.isEmpty {
                        selectedDay = 1
                        dayText = "1일"
                    }
                    showDayPicker = true
                } label: {
                    Text(dayText.isEmpty ? "언제?" : dayText)
                        .font(.custom("PretendardVariable-Bold", size: 14))
                        .foregroundStyle(dayText.isEmpty
                                         ? Color(uiColor: .placeholderText)
                                         : Color("customLabel"))
                        .frame(maxWidth: .infinity)
                }
                .frame(width: 70)

                TextField("어디서?", text: $towhat)
                    .font(.custom("PretendardVariable-SemiBold", size: 14))
                    .foregroundStyle(Color("customLabel"))
                    .multilineTextAlignment(.center)
                    .focused($focused, equals: .towhat)
                    .submitLabel(.next)
                    .onSubmit { focused = .how }
                    .onChange(of: towhat) { _, new in
                        if new.count > 15 { towhat = String(new.prefix(15)) }
                    }

                TextField("얼마?", text: $howText)
                    .font(.custom("PretendardVariable-SemiBold", size: 14))
                    .foregroundStyle(Color("customLabel"))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .focused($focused, equals: .how)
                    .onChange(of: howText) { _, new in
                        // 실시간 반점 + 11자(반점 포함) 제한
                        let raw = new.replacingOccurrences(of: ",", with: "")
                        if raw.isEmpty {
                            howText = ""
                        } else if let int = Int(raw) {
                            let formatted = int.toDecimal()
                            howText = formatted.count > 11 ? String(formatted.prefix(11)) : formatted
                        }
                    }
            }
            .frame(height: 50)

            // 하단 줄 (fixedColor 1.5pt)
            Rectangle()
                .fill(Color("fixedColor"))
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
                    // 섹션 헤더 "n일"
                    Text("\(group.day)일")
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
                    .font(.custom("PretendardVariable-SemiBold", size: 14))
                    .foregroundStyle(Color("customLabel"))
                    .lineLimit(1)

                Spacer()

                Text("\(item.how.toDecimal()) 원")
                    .font(.custom("PretendardVariable-SemiBold", size: 16))
                    .foregroundStyle(Color("customLabel"))

                Button {
                    deleteTarget = item
                } label: {
                    Image(systemName: "trash.square")
                        .font(.system(size: 22))
                        .foregroundStyle(Color("fixedColor"))
                        .frame(width: 50, height: 50)
                }
            }
            .frame(height: 36)

            // 행 하단 줄 (systemGray6 1.5pt)
            Rectangle()
                .fill(Color(uiColor: .systemGray6))
                .frame(height: 1.5)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 데이터 조작

    private func addItem() {
        guard canAdd else { return }

        let entity = FixedExpenditureEntity(
            day: selectedDay,
            towhat: towhat,
            how: howText.toInt()
        )
        modelContext.insert(entity)
        try? modelContext.save()

        // 푸시 알림 등록 (externalID를 식별자로 사용)
        notificationCenter.addNotificationRequest(
            to: nickName,
            by: FixedExpenditure(id: entity.externalID, day: entity.day, towhat: entity.towhat, how: entity.how)
        )

        // 입력 초기화
        dayText = ""
        towhat = ""
        howText = ""
        focused = nil

    }

    private func deleteItem(_ item: FixedExpenditureEntity) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [item.externalID])
        modelContext.delete(item)
        try? modelContext.save()
    }

    // MARK: - 알림

    private func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
                print(error)
            }
        }
    }

    // 화면 진입시 등록된 고정 지출 전체 알림 재등록 (기존 fixedExpenditureVC.viewDidLoad와 동일)
    private func rescheduleAllNotifications() {
        guard !fixedItems.isEmpty else { return }
        notificationCenter.removeAllPendingNotificationRequests()
        for item in fixedItems {
            notificationCenter.addNotificationRequest(
                to: nickName,
                by: FixedExpenditure(id: item.externalID, day: item.day, towhat: item.towhat, how: item.how)
            )
        }
    }

    // MARK: - Dismiss

    private func performDismiss() {
        // calendarVC가 직접 present한 UIHostingController이므로 SwiftUI dismiss로 충분
        swiftUIDismiss()
    }
}

// MARK: - 일(day) 선택 시트

struct DaySelectorSheet: View {
    @Binding var selectedDay: Int
    let onConfirm: (Int) -> Void

    var body: some View {
        NavigationStack {
            Picker("일", selection: $selectedDay) {
                ForEach(1...31, id: \.self) { day in
                    Text("\(day)일").tag(day)
                }
            }
            .pickerStyle(.wheel)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("설정") {
                        onConfirm(selectedDay)
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
