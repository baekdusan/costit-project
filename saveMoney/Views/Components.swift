import SwiftUI
import SwiftData

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

    // 단일 확인 버튼만 있는 안내/오류 알럿 공통 패턴 — message가 non-nil이면 표시
    func messageAlert(
        _ title: String = "알림",
        message: Binding<String?>
    ) -> some View {
        alert(title, isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("확인") { message.wrappedValue = nil }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

// 직전 알럿(예: 삭제 확인 알럿)이 닫히는 도중에 곧바로 다음 알럿을 띄우면 표시 요청이 무시된다.
// 또한 이전 요청이 무시돼 값이 non-nil로 굳어 있으면 재대입에 전이가 없어 알럿이 뜨지 않으므로,
// 먼저 nil로 비운 뒤 닫힘 애니메이션 이후(0.4s)에 메시지를 채운다.
func presentDeferredAlertMessage(_ text: String, to binding: Binding<String?>) {
    binding.wrappedValue = nil
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        binding.wrappedValue = text
    }
}

// MARK: - 년/월 선택 시트 (MainView / RevenueView 공통)

struct MonthSelectorSheet: View {
    let onSelect: (Date, Date, String) -> Void
    let onReset: () -> Void

    // 실제로 저장된 내역의 연도 범위를 함께 보여준다 — 목록에 없는 연도는 조회 자체가 불가능해
    // "저장은 됐는데 어디서도 볼 수 없는" 데이터가 생긴다 (입력 화면의 DatePicker에는 연도 제한이 없다).
    // 필요한 건 최초/최종 1건뿐이라 @Query로 전 내역을 메모리에 올리지 않고 fetchLimit 1로 양 끝만 읽는다.
    @Environment(\.modelContext) private var modelContext

    // 날짜 산술은 프로젝트 전체가 gregorian 고정 — 여기만 Calendar.current를 쓰면
    // 비양력 기기(불교력 등)에서 선택한 연도가 전혀 다른 절대 날짜로 해석되어
    // 해당 기간 내역이 통째로 사라진다.
    // static let이 아닌 computed인 이유는 Date 확장과 동일: Calendar는 생성 시점의 타임존을
    // 스냅샷하므로, 캐시해두면 기기 타임존이 바뀐 뒤 라벨과 실제 필터 기간이 어긋난다.
    private static var gregorian: Calendar { Calendar(identifier: .gregorian) }

    @State private var selectedYear: Int = Calendar(identifier: .gregorian).component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar(identifier: .gregorian).component(.month, from: Date())

    private var years: [Int] {
        let calendar = Self.gregorian
        let current = calendar.component(.year, from: Date())

        var oldest = FetchDescriptor<FinDataEntity>(sortBy: [SortDescriptor(\.when)])
        oldest.fetchLimit = 1
        var newest = FetchDescriptor<FinDataEntity>(sortBy: [SortDescriptor(\.when, order: .reverse)])
        newest.fetchLimit = 1
        let storedMin = (try? modelContext.fetch(oldest))?.first.map { calendar.component(.year, from: $0.when) }
        let storedMax = (try? modelContext.fetch(newest))?.first.map { calendar.component(.year, from: $0.when) }

        // 디바이스 시계가 2021 이전으로 설정돼 있어도 빈 Range 크래시가 나지 않도록 가드.
        // 상·하한을 두는 이유: 입력 화면 DatePicker에 연도 제한이 없어 실수로 0001년 내역이
        // 하나라도 저장되면 wheel Picker 항목이 수천 개로 불어난다.
        let lower = max(AppYearBounds.minYear, min(AppYearBounds.defaultMinYear, storedMin ?? AppYearBounds.defaultMinYear))
        let upper = min(AppYearBounds.maxYear, max(current, storedMax ?? current))
        return Array(lower...max(lower, upper))
    }

    var body: some View {
        // NavigationStack의 toolbar 버튼은 UIKit present된 UIHostingController 위에서 띄운
        // sheet에서는 탭이 먹지 않는 경우가 있어(수입 화면) 일반 버튼 헤더로 구성한다.
        VStack(spacing: 0) {
            HStack {
                Button("Reset", action: onReset)
                Spacer()
                Button("설정") {
                    let comps = DateComponents(year: selectedYear, month: selectedMonth)
                    guard let date = Self.gregorian.date(from: comps) else { return }
                    let label = "🗓 \(selectedYear)년 \(selectedMonth)월"
                    onSelect(date.startOfThisMonth, date.endOfThisMonth, label)
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .tint(Color(.customLabel))
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 4)

            HStack(spacing: 0) {
                Picker("년", selection: $selectedYear) {
                    ForEach(years, id: \.self) { year in
                        // Text("\(year)년")은 LocalizedStringKey 보간이라 "2,026년"처럼 천 단위 콤마가 붙음 → verbatim 사용
                        Text(verbatim: "\(year)년").tag(year)
                    }
                }
                .pickerStyle(.wheel)

                Picker("월", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(verbatim: "\(month)월").tag(month)
                    }
                }
                .pickerStyle(.wheel)
            }
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
