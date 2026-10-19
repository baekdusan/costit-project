import SwiftUI
import SwiftData

struct AddFinView: View {

    enum Source { case expense, revenue }

    enum Mode {
        case new
        case edit(EditTarget)

        // 편집 대상을 @Model 인스턴스로 들고 있으면, 화면이 떠 있는 동안 다른 기기의 삭제가
        // CloudKit으로 동기화됐을 때 속성 접근만으로 크래시한다(invalidated backing data).
        // 표시/저장에 필요한 값만 복사해 보관하고, 실제 저장은 externalID로 다시 찾는다.
        struct EditTarget {
            let externalID: String
            let when: Date
            let towhat: String
            let how: Int

            init(_ item: FinDataEntity) {
                externalID = item.externalID
                when = item.when
                towhat = item.towhat
                how = item.how
            }
        }
    }

    @Environment(\.modelContext) private var modelContext

    let source: Source
    let mode: Mode
    // present한 쪽이 주입하는 닫기 동작 (UIKit present라 SwiftUI dismiss 대신 호스트 VC를 직접 dismiss)
    let onDismiss: () -> Void

    @State private var when: Date = Date()
    @State private var towhat: String = ""
    @State private var howText: String = ""
    @State private var showDatePicker: Bool = false
    @State private var isSaving: Bool = false          // 저장 버튼 연타로 중복 레코드가 생기는 것 방지
    @State private var saveFailureMessage: String?     // 저장 실패 시 화면을 닫지 않고 알림
    @FocusState private var focused: Field?

    // 스와이프 dismiss용
    @GestureState private var dragOffset: CGFloat = 0

    enum Field: Hashable { case towhat, how }

    private var howInt: Int {
        howText.toInt()   // toInt()가 콤마 처리 포함
    }

    private var trimmedTowhat: String {
        towhat.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedTowhat.isEmpty && !howText.isEmpty
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
                                let formatted = new.currencyInputFormatted(limit: .rawDigits(15))
                                if formatted != new { howText = formatted }
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
                // 연도 범위를 열어두면 휠을 0001년까지 돌려 저장할 수 있고, 그 내역은
                // 월 선택 시트(MonthSelectorSheet)의 연도 목록을 수천 개로 불어나게 한다
                DatePicker("날짜", selection: $when, in: AppYearBounds.selectableDateRange, displayedComponents: .date)
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
        // 저장 실패/대상 소실을 알린다 — 화면은 닫지 않으므로 입력값이 보존된다
        .messageAlert(message: $saveFailureMessage)
    }

    // MARK: - 데이터 조작 / Dismiss

    private func prefill() {
        if case .edit(let target) = mode {
            when = target.when
            towhat = target.towhat
            howText = target.how.toDecimal()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focused = .towhat
        }
    }

    private func save() {
        // 저장이 진행 중이면 무시 — dismiss 애니메이션 중 두 번째 탭이 들어오면
        // .new 경로가 엔티티를 한 번 더 insert해 같은 지출이 두 건 저장된다.
        guard canSave, !isSaving else { return }
        isSaving = true

        // 저장 실패 시 되돌리기 위해 이번에 새로 insert한 엔티티를 기억해둔다.
        // (되돌리지 않으면 pending insert가 컨텍스트에 남아, 사용자가 알럿을 닫고 다시
        //  저장을 누를 때 두 번째 엔티티가 또 insert되어 같은 지출이 두 건이 된다)
        var insertedEntity: FinDataEntity?
        var editedEntity: FinDataEntity?
        var previousValues: (when: Date, towhat: String, how: Int)?

        // 모든 present 경로가 withAppEnvironment()로 공용 ModelContainer를 주입하므로
        // 다른 화면들과 동일하게 environment context를 사용한다.
        switch mode {
        case .new:
            let entity = FinDataEntity(
                when: when.truncatingSubseconds,
                towhat: trimmedTowhat,
                how: howInt,
                isRevenue: source == .revenue
            )
            modelContext.insert(entity)
            insertedEntity = entity
        case .edit(let target):
            // edit 대상은 다른 context에서 fetch된 인스턴스일 수 있으므로 externalID로 다시 찾음
            let externalID = target.externalID
            let descriptor = FetchDescriptor<FinDataEntity>(
                predicate: #Predicate { $0.externalID == externalID }
            )
            // 조회 실패(throw)와 "정말 삭제됨"을 구분한다 — 뭉개면 조회만 실패했는데도
            // "다른 기기에서 삭제된 내역"이라고 잘못 단정하게 된다
            guard let found = try? modelContext.fetch(descriptor) else {
                PersistenceController.logger.error("AddFinView edit 대상 조회 실패: externalID \(externalID, privacy: .public)")
                isSaving = false
                saveFailureMessage = "저장에 실패했어요. 잠시 후 다시 시도해주세요."
                return
            }
            // isDeleted도 함께 본다 — 편집 화면을 열어둔 사이 다른 기기의 삭제가 동기화되면
            // 삭제 표시만 된 인스턴스가 조회될 수 있고, 그 속성을 고치면 이미 지워진 레코드를
            // 되살리거나 컨텍스트를 오염시킨다 (PersistenceController.deleteFin과 같은 판정).
            guard let entity = found.first(where: { !$0.isDeleted }) else {
                // edit 도중 다른 기기에서 삭제된 경우 등. 과거엔 조용히 무시하고 화면을 닫아
                // 사용자는 수정이 저장된 것으로 오인했다 → 입력을 유지한 채 사실을 알린다.
                PersistenceController.logger.error("AddFinView edit 대상 미발견: externalID \(externalID, privacy: .public)")
                isSaving = false
                saveFailureMessage = "다른 기기에서 삭제된 내역이라 수정할 수 없어요."
                return
            }
            // 저장이 실패하면 되돌리기 위해 원래 값을 기억해둔다 (pending 변경이 남으면
            // "저장 실패" 알럿과 달리 autosave가 뒤늦게 커밋해 결과가 모순된다)
            editedEntity = entity
            previousValues = (entity.when, entity.towhat, entity.how)

            entity.when = when.truncatingSubseconds
            entity.towhat = trimmedTowhat
            entity.how = howInt
        }

        // 저장 실패 시 화면을 닫으면 사용자가 입력한 내역이 그대로 사라진다 → 열어둔 채 알림.
        // 이번 변경(insert / 속성 수정)은 되돌려 재시도 때 중복이 쌓이거나
        // 화면과 실제 저장 결과가 어긋나지 않게 한다.
        guard PersistenceController.saveAndRefreshWidgets(modelContext) else {
            if let insertedEntity {
                modelContext.delete(insertedEntity)
            }
            if let editedEntity, let previousValues {
                editedEntity.when = previousValues.when
                editedEntity.towhat = previousValues.towhat
                editedEntity.how = previousValues.how
            }
            isSaving = false
            saveFailureMessage = "저장에 실패했어요. 잠시 후 다시 시도해주세요."
            return
        }

        focused = nil
        performDismiss()
    }

    private func performDismiss() {
        onDismiss()
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        AddFinView(source: .revenue, mode: .new, onDismiss: {})
            .modelContainer(PreviewSampleData.container)
    }
}
