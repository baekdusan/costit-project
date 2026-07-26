import SwiftUI

// firstOpenVC를 SwiftUI로 옮긴 버전.
// UIKit 호스트(mainVC)와 데이터 주고받기는 onConfirm 콜백 한 줄로 처리.
// 화면을 storyboard segue 대신 UIHostingController로 띄우는 게 점진 전환 방식.
struct FirstOpenView: View {

    // true면 첫 실행 (빈 입력 + 닉네임에 자동 포커스), false면 프로필 편집 (기존 값 채워서 표시)
    let isFirstOpen: Bool

    // 완료 시 호출. (nickname, outLay, period)
    let onConfirm: (String, Int, String) -> Void

    /// 첫 실행용 — 빈 입력 상태로 시작.
    init(onConfirm: @escaping (String, Int, String) -> Void) {
        self.isFirstOpen = true
        self.onConfirm = onConfirm
        // @State 기본값이 이미 빈 입력 상태
    }

    /// 프로필 편집용 — 기존 값으로 입력 채워줌.
    // (onAppear 초기화 패턴은 UIKit present 경로에서 발화하지 않을 수 있어 init에서 State를 직접 채움)
    init(editing profile: Profile,
         onConfirm: @escaping (String, Int, String) -> Void) {
        self.isFirstOpen = false
        self.onConfirm = onConfirm
        _nickname = State(initialValue: profile.nickName)
        _outLayText = State(initialValue: profile.outLay > 0 ? profile.outLay.toDecimal() : "")
        _period = State(initialValue: profile.period.isEmpty ? SalaryDay.firstDay : profile.period)
    }

    @State private var nickname: String = ""
    @State private var outLayText: String = ""
    @State private var period: String = SalaryDay.firstDay
    @State private var showSalaryPicker: Bool = false

    @FocusState private var focused: Field?

    enum Field: Hashable { case nickname, outLay }

    private static let salaryOptions: [String] =
        (1...30).map(SalaryDay.day) + [SalaryDay.lastDay]

    private var outLayInt: Int {
        outLayText.toInt()   // toInt()가 콤마 처리 포함
    }

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isAllFilled: Bool {
        !trimmedNickname.isEmpty && !outLayText.isEmpty && !period.isEmpty
    }

    var body: some View {
        // 입력 stack 폭을 storyboard와 동일하게 safe area의 80%로 맞추기 위해
        // GeometryReader로 폭 계산 후 입력 stack에 명시적 width 부여.
        GeometryReader { proxy in
            VStack {
                inputStack
                    .frame(width: proxy.size.width * 0.8)
                    .padding(.top, 30)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.background))
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("완료", action: confirm)
                    .tint(Color(.customLabel))
                    .disabled(!isAllFilled)
            }
        }
        // 배경을 visible로 만들면 네비게이션 바 아래 분리선(hairline)이 생기므로 hidden 사용.
        // 화면 배경(backgroundColor)이 그대로 비쳐서 시각적으로 동일하다.
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSalaryPicker) {
            salaryPickerSheet
        }
        .onAppear {
            if isFirstOpen {
                focused = .nickname
            }
        }
    }

    private var inputStack: some View {
        VStack(spacing: 30) {
            field(
                placeholder: "닉네임을 입력해주세요.",
                text: $nickname,
                keyboard: .default,
                focusBinding: .nickname,
                next: .outLay
            )

            field(
                placeholder: "이번 달 목표 지출액은요?",
                text: $outLayText,
                keyboard: .numberPad,
                focusBinding: .outLay,
                next: nil
            )
            .onChange(of: outLayText) { _, newValue in
                // rawDigits(15): 과거 무제한이라 Int 범위 초과 입력 시 화면엔 큰 숫자,
                // 저장은 0이 되는 조용한 유실이 있었음 (지출 입력과 동일한 15자리 가드)
                let formatted = newValue.currencyInputFormatted(limit: .rawDigits(15))
                if formatted != newValue { outLayText = formatted }
            }

            VStack(alignment: .trailing, spacing: 10) {
                Button {
                    focused = nil
                    showSalaryPicker = true
                } label: {
                    Text(period.isEmpty ? "매달 언제마다?" : "매월 \(period)")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(period.isEmpty ? Color(uiColor: .placeholderText) : Color(.customLabel))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .frame(height: 25.5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Color(.header)
                    .frame(height: 2)
                    .opacity(0.5)

                Text("급여가 일정하지 않다면, 1일이 편해요.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(uiColor: .systemGray3))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func field(
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        focusBinding: Field,
        next: Field?
    ) -> some View {
        VStack(spacing: 10) {
            TextField(placeholder, text: text)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color(.customLabel))
                .keyboardType(keyboard)
                .focused($focused, equals: focusBinding)
                .submitLabel(next == nil ? .done : .next)
                .onSubmit {
                    if let next {
                        focused = next
                    } else {
                        focused = nil
                        showSalaryPicker = true
                    }
                }
                .frame(height: 25.5)
                // 닉네임 15자 제한 (기존 로직 유지)
                .onChange(of: text.wrappedValue) { _, newValue in
                    if focusBinding == .nickname && newValue.count > 15 {
                        text.wrappedValue = String(newValue.prefix(15))
                    }
                }

            Color(.header)
                .frame(height: 2)
                .opacity(0.5)
        }
    }

    private var salaryPickerSheet: some View {
        NavigationStack {
            Picker("급여일", selection: $period) {
                ForEach(Self.salaryOptions, id: \.self) { day in
                    Text(day).tag(day)
                }
            }
            .pickerStyle(.wheel)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { showSalaryPicker = false }
                }
            }
        }
        .presentationDetents([.fraction(0.35)])
    }

    private func confirm() {
        guard isAllFilled else { return }
        onConfirm(trimmedNickname, outLayInt, period)
    }
}

#Preview {
    NavigationStack {
        FirstOpenView { nickname, outLay, period in
            print("confirm:", nickname, outLay, period)
        }
    }
}
