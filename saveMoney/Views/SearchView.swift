import SwiftUI
import SwiftData

// searchVC를 SwiftUI로 옮긴 버전. SwiftData에서 직접 쿼리.
struct SearchView: View {

    @Query(filter: #Predicate<FinDataEntity> { $0.isRevenue == false },
           sort: \FinDataEntity.when, order: .reverse)
    private var expenses: [FinDataEntity]

    @Query(filter: #Predicate<FinDataEntity> { $0.isRevenue == true },
           sort: \FinDataEntity.when, order: .reverse)
    private var revenues: [FinDataEntity]

    @State private var query: String = ""

    // 지출·수입 필터를 한 번에 계산한다.
    // 캐시 없는 computed로 두면 body 한 번에 각각 두 번씩 접근되어(isEmpty 검사 + 목록 전달)
    // 전건을 4회 훑는다. 한글 IME는 자모마다 textDidChange를 발화시키므로 글자 하나에
    // 이 비용이 여러 번 반복돼 대량 데이터에서 입력이 눈에 띄게 밀린다.
    private struct Results {
        var expenses: [FinDataEntity] = []
        var revenues: [FinDataEntity] = []
        var isEmpty: Bool { expenses.isEmpty && revenues.isEmpty }
    }

    private func makeResults() -> Results {
        // 저장 시 품목명은 trim되므로(AddFinView) 검색어도 앞뒤 공백을 떼야 매칭된다
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return Results() }
        return Results(
            expenses: expenses.filter { $0.towhat.lowercased().contains(q) },
            revenues: revenues.filter { $0.towhat.lowercased().contains(q) }
        )
    }

    var body: some View {
        GeometryReader { proxy in
            // 다른 화면과 일관성 위해 컨텐츠 폭은 화면의 80%로 제한
            let contentWidth = proxy.size.width * 0.8

            // 필터는 body 평가당 한 번만 수행한다
            let results = makeResults()

            ScrollView {
                // ForEach를 LazyVStack 직속에 둬야 지연 생성이 실제로 동작한다.
                // 중간에 VStack을 끼우면 그 하나를 실체화하는 순간 매칭된 전건의 셀이
                // 한꺼번에 생성·레이아웃되어, 결과가 많을 때 키 입력마다 화면이 멈춘다.
                LazyVStack(spacing: 0, pinnedViews: []) {
                    if !results.expenses.isEmpty {
                        sectionHeader("💸 지출")
                        ForEach(results.expenses) { rowCell($0) }
                    }
                    if !results.revenues.isEmpty {
                        sectionHeader("💰 수입")
                        ForEach(results.revenues) { rowCell($0) }
                    }
                }
                .frame(width: contentWidth)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SearchBarRepresentable(
                        text: $query,
                        placeholder: "품목을 입력해봐요 :)",
                        becomeFirstResponderOnAppear: true
                    )
                    .frame(width: max(0, proxy.size.width - 80))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .opacity(0.72)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 30)
    }

    private func rowCell(_ item: FinDataEntity) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                // "26. 05. 08" 형식 (yy. MM. dd). 셀에서만 쓰는 짧은 표기.
                Text(AppDateFormatters.shortDate.string(from: item.when))
                    .font(.pretendard(.regular, size: 12))
                    .foregroundStyle(Color(.customLabel))
                    .fixedSize()

                Text(item.towhat)
                    .font(.pretendard(.medium, size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)

                Text("\(item.how.toDecimal()) 원")
                    .font(.pretendard(.semiBold, size: 16))
                    .fixedSize()
            }
            .padding(.vertical, 18)

            HairlineDivider()
        }
    }

}

#Preview {
    NavigationStack {
        SearchView()
            .modelContainer(PreviewSampleData.container)
    }
}
