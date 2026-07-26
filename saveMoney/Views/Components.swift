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

// 화면마다 다른 입력 길이 제한만 파라미터로 둔다.
// 주의: "제한 없음" case는 두지 않는다 — Int 범위 초과 붙여넣기가 toInt()의 0 폴백으로
// 조용히 유실되는 경로가 생기므로 (fix 523a76c), 새 금액 필드도 반드시 자릿수 제한을 골라야 함.
enum CurrencyInputLimit {
    case rawDigits(Int)       // 숫자 자릿수 제한 (AddFinView/FirstOpenView: 15)
    case formattedChars(Int)  // 콤마 포함 문자수 제한 (FixedExpenditureView: 11)
}

extension String {
    // 입력에서 ASCII 숫자만 살려 콤마 포맷을 붙인다.
    // 불변식: 반환값은 항상 "화면에 보이는 값 == 저장될 값(toInt())"을 만족한다.
    //
    // 과거 구현이 이 불변식을 깨던 경로들:
    //  (1) formattedChars 제한을 콤마 포함 문자열에 prefix로 적용 → 1,234,567,890 입력이
    //      화면엔 "1,234,567,8", 저장은 12,345,678로 서로 다른 값이 됨
    //  (2) Int("-123") 파싱 성공 → 음수 금액이 그대로 저장되어 합계가 반대로 계산됨
    //  (3) filter(\.isNumber)가 전각 숫자(１２３)를 통과 → 화면엔 남지만 toInt()는 0
    //  (4) keepAsIs 정책이 "₩123" 같은 입력을 그대로 둬서 저장 시 0원
    //  (5) 선행 0을 자릿수로 세고 먼저 절삭 → "0000000000000001"이 0으로 저장
    func currencyInputFormatted(limit: CurrencyInputLimit) -> String {
        // isNumber는 전각 숫자·타 문자권 숫자에도 true라 부적합. ASCII 숫자만 남긴다.
        // (마이너스 기호·통화 기호·공백도 여기서 전부 탈락)
        var digits = filter { $0.isASCII && $0.isNumber }

        // 선행 0 제거를 자릿수 절삭보다 먼저 — 순서가 반대면 유효 숫자가 잘려나간다
        while digits.count > 1 && digits.hasPrefix("0") {
            digits.removeFirst()
        }
        if digits.isEmpty { return "" }

        let maxDigits: Int
        switch limit {
        case .rawDigits(let count):
            maxDigits = max(1, count)
        case .formattedChars(let count):
            // 콤마 포함 count자를 넘지 않는 최대 자릿수 (d자리의 표시 길이 = d + (d-1)/3)
            maxDigits = max(1, (count * 3 + 3) / 4)
        }
        if digits.count > maxDigits {
            digits = String(digits.prefix(maxDigits))
        }

        // 자릿수를 제한한 뒤이므로 파싱은 항상 성공한다 (?? 는 방어용)
        return Int(digits).map { $0.toDecimal() } ?? digits
    }
}
