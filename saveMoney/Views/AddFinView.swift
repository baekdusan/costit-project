import SwiftUI
import SwiftData

struct AddFinView: View {

    enum Source { case expense, revenue }
    enum Mode { case new, edit(FinDataEntity) }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let source: Source
    let mode: Mode

    @State private var when: Date = Date()
    @State private var towhat: String = ""
    @State private var howText: String = ""
    @State private var showDatePicker: Bool = false
    @FocusState private var focused: Field?

    // 스와이프 dismiss용
    @GestureState private var dragOffset: CGFloat = 0

    enum Field: Hashable { case towhat, how }

    private var howInt: Int {
        howText.toInt()   // toInt()가 콤마 처리 포함
    }

    private var canSave: Bool {
        !towhat.isEmpty && !howText.isEmpty
    }

    // "26. 5. 9." (앞 20 빼고 한 자리 숫자 그대로)
    private var formattedDate: String {
        AppDateFormatters.editDate.string(from: when)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let cardSize = proxy.size.width * 0.5
            // storyboard 원본 constraint: card.centerY = view.centerY * 2/3
            // 즉 카드 중심이 화면 세로의 1/3 지점 (위쪽).
            let cardCenterY = proxy.size.height / 3

            ZStack {
                // 반투명 배경 (탭 → dismiss)
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        focused = nil
                        performDismiss()
                    }

                // 메모지 카드
                ZStack {
                    Color(.memoPaper)
                        .frame(width: cardSize, height: cardSize)

                    VStack(alignment: .leading, spacing: 0) {
                        // 1줄: 날짜(좌) + X(우) — 같은 높이
                        HStack(alignment: .center, spacing: 0) {
                            // 날짜: 탭하면 wheel picker sheet
                            Button {
                                focused = nil
                                showDatePicker = true
                            } label: {
                                Text(formattedDate)
                                    .font(.pretendard(.medium, size: 14))
                                    .foregroundStyle(Color(.customLabel))
                                    .frame(height: 22)
                            }

                            Spacer()

                            Button {
                                focused = nil
                                performDismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color(.customLabel).opacity(0.5))
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .padding(.top, cardSize * 0.07)

                        // 어디서?
                        TextField("어디서?", text: $towhat)
                            .font(.pretendard(.medium, size: 20))
                            .foregroundStyle(Color(.customLabel))
                            .focused($focused, equals: .towhat)
                            .submitLabel(.next)
                            .onSubmit { focused = .how }
                            .onChange(of: towhat) { _, new in
                                if new.count > 30 { towhat = String(new.prefix(30)) }
                            }
                            .padding(.top, cardSize * 0.05)

                        Spacer()

                        // 얼마?
                        TextField("얼마?", text: $howText)
                            .font(.pretendard(.semiBold, size: 20))
                            .foregroundStyle(Color(.customLabel))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .focused($focused, equals: .how)
                            .onChange(of: howText) { _, new in
                                if let formatted = new.currencyInputFormatted(limit: .rawDigits(15), onParseFailure: .filterDigits) {
                                    howText = formatted
                                }
                            }
                            .padding(.bottom, cardSize * 0.1)
                    }
                    .padding(.horizontal, cardSize * 0.07)
                    .frame(width: cardSize, height: cardSize)

                    // 저장 체크 버튼 (우측 하단 바깥)
                    if canSave {
                        Button(action: save) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .background(Color(.customLabel))
                                .foregroundStyle(Color(.background))
                                .clipShape(Circle())
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, -22)
                        .padding(.bottom, -22)
                    }
                }
                .frame(width: cardSize, height: cardSize)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                // 스와이프 아래로 드래그 오프셋 반영
                .offset(y: max(0, dragOffset))
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            if value.translation.height > 80 {
                                focused = nil
                                performDismiss()
                            }
                        }
                )
                .position(x: proxy.size.width / 2, y: cardCenterY)
            }
            .ignoresSafeArea(.keyboard)
        }
        .ignoresSafeArea(.keyboard)
        .onAppear(perform: prefill)
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                DatePicker("날짜", selection: $when, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    .frame(maxWidth: .infinity)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("완료") {
                                showDatePicker = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    focused = .towhat
                                }
                            }
                        }
                    }
            }
            .presentationDetents([.fraction(0.4)])
        }
    }

    // MARK: - 데이터 조작 / Dismiss

    private func prefill() {
        if case .edit(let item) = mode {
            when = item.when
            towhat = item.towhat
            howText = item.how.toDecimal()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focused = .towhat
        }
    }

    private func save() {
        guard canSave else { return }
        // 모든 present 경로가 .modelContainer(PersistenceController.shared)를 주입하므로
        // 다른 화면들과 동일하게 environment context를 사용한다.
        switch mode {
        case .new:
            let entity = FinDataEntity(
                when: when,
                towhat: towhat,
                how: howInt,
                isRevenue: source == .revenue
            )
            modelContext.insert(entity)
        case .edit(let item):
            // edit 대상은 다른 context에서 fetch된 인스턴스일 수 있으므로 externalID로 다시 찾음
            let externalID = item.externalID
            let descriptor = FetchDescriptor<FinDataEntity>(
                predicate: #Predicate { $0.externalID == externalID }
            )
            if let target = (try? modelContext.fetch(descriptor))?.first {
                target.when = when
                target.towhat = towhat
                target.how = howInt
            } else {
                // edit 도중 다른 기기에서 삭제된 경우 등 — 기존과 동일하게 조용히 무시 (관측용 로그만)
                PersistenceController.logger.error("AddFinView edit 대상 미발견: externalID \(externalID, privacy: .public)")
            }
        }
        PersistenceController.saveAndRefreshWidgets(modelContext)
        focused = nil
        performDismiss()
    }

    private func performDismiss() {
        // SwiftUI dismiss action 우선, 실패 시 UIKit 직접 dismiss
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            UIApplication.shared.appRootViewController?
                .topMostPresentedViewController
                .dismiss(animated: false)
        }
    }
}

private extension UIViewController {
    var topMostPresentedViewController: UIViewController {
        var top = self
        while let next = top.presentedViewController {
            top = next
        }
        return top
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        AddFinView(source: .revenue, mode: .new)
            .modelContainer(PreviewSampleData.container)
    }
}
