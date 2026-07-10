import SwiftUI

// MARK: - 하단 원형 액션 버튼 (메인/수입 화면 공통)

struct CircleActionButton: View {
    let systemName: String
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 60, height: 60)
                .background(background)
                .foregroundStyle(Color(.background))
                .clipShape(Circle())
        }
    }
}

// MARK: - 1.5pt 헤어라인 구분선 (systemGray6 — 패딩은 호출부 책임)

struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(uiColor: .systemGray6))
            .frame(height: 1.5)
    }
}

// MARK: - 공통 View 확장

extension View {
    // 메모지/카드 공통 그림자 (y 오프셋만 화면마다 다름: 메인 6 / 수입 5 / 캘린더 -4)
    func paperShadow(y: CGFloat) -> some View {
        shadow(color: .black.opacity(0.08), radius: 6, y: y)
    }

    // 삭제 확인 알럿 공통 패턴 — item이 nil이 아니면 표시, 확인 시 onConfirm(대상) 호출
    func deleteConfirmationAlert<T>(
        item: Binding<T?>,
        message: String,
        onConfirm: @escaping (T) -> Void
    ) -> some View {
        alert("삭제", isPresented: Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )) {
            Button("취소", role: .cancel) { item.wrappedValue = nil }
            Button("확인") {
                if let target = item.wrappedValue {
                    onConfirm(target)
                }
                item.wrappedValue = nil
            }
        } message: {
            Text(message)
        }
    }
}

// MARK: - 금액 입력 실시간 콤마 포맷

// 두 화면군의 기존 변종 동작을 파라미터로 보존한다 (동작 통일은 별도 결정 사항).
// 주의: "제한 없음" case는 두지 않는다 — Int 범위 초과 붙여넣기가 toInt()의 0 폴백으로
// 조용히 유실되는 경로가 생기므로 (fix 523a76c), 새 금액 필드도 반드시 자릿수 제한을 골라야 함.
enum CurrencyInputLimit {
    case rawDigits(Int)       // 콤마 제거 기준 자릿수 제한 — 초과 시 콤마 없이 절삭 (AddFinView/FirstOpenView: 15)
    case formattedChars(Int)  // 콤마 포함 문자수 제한 (FixedExpenditureView: 11)
}

enum CurrencyParseFailurePolicy {
    case filterDigits   // 숫자만 남김 (AddFinView / FirstOpenView)
    case keepAsIs       // 입력 그대로 유지 (FixedExpenditureView)
}

extension String {
    // 반환값이 nil이면 "기존 입력 유지" (호출부에서 대입 생략)
    func currencyInputFormatted(
        limit: CurrencyInputLimit,
        onParseFailure: CurrencyParseFailurePolicy
    ) -> String? {
        let raw = replacingOccurrences(of: ",", with: "")
        if raw.isEmpty { return "" }

        if case .rawDigits(let maxDigits) = limit, raw.count > maxDigits {
            return String(raw.prefix(maxDigits))
        }

        func format(_ int: Int) -> String {
            let formatted = int.toDecimal()
            if case .formattedChars(let maxChars) = limit, formatted.count > maxChars {
                return String(formatted.prefix(maxChars))
            }
            return formatted
        }

        if let int = Int(raw) {
            return format(int)
        }

        // Int 파싱 실패 = 숫자가 아니거나 Int 범위 초과(20자리 이상 붙여넣기 등)
        switch onParseFailure {
        case .filterDigits:
            return String(raw.filter(\.isNumber))
        case .keepAsIs:
            // 범위 초과 숫자를 그대로 두면 화면엔 큰 숫자, 저장은 toInt()의 0 폴백으로
            // 조용히 유실됨 → 숫자로만 이뤄진 입력은 15자리로 절삭 후 재포맷
            if raw.allSatisfy(\.isNumber), let int = Int(String(raw.prefix(15))) {
                return format(int)
            }
            return nil
        }
    }
}
