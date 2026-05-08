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

    private var filteredExpenses: [FinDataEntity] {
        let q = query.lowercased()
        guard !q.isEmpty else { return [] }
        return expenses.filter { $0.towhat.lowercased().contains(q) }
    }

    private var filteredRevenues: [FinDataEntity] {
        let q = query.lowercased()
        guard !q.isEmpty else { return [] }
        return revenues.filter { $0.towhat.lowercased().contains(q) }
    }

    var body: some View {
        GeometryReader { proxy in
            // 다른 화면과 일관성 위해 컨텐츠 폭은 화면의 80%로 제한
            let contentWidth = proxy.size.width * 0.8

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    if !filteredExpenses.isEmpty {
                        section(title: "💸 지출", items: filteredExpenses)
                    }
                    if !filteredRevenues.isEmpty {
                        section(title: "💰 수입", items: filteredRevenues)
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

    private func section(title: String, items: [FinDataEntity]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .opacity(0.72)
                .frame(height: 30, alignment: .leading)

            ForEach(items) { item in
                rowCell(item)
            }
        }
    }

    private func rowCell(_ item: FinDataEntity) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                Text(Self.shortDate(item.when))
                    .font(.custom("PretendardVariable-Regular", size: 14))
                    .foregroundStyle(Color("customLabel"))
                    .fixedSize()

                Text(item.towhat)
                    .font(.custom("PretendardVariable-Medium", size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)

                Text("\(item.how.toDecimal()) 원")
                    .font(.custom("PretendardVariable-SemiBold", size: 14))
                    .fixedSize()
            }
            .padding(.vertical, 18)

            Rectangle()
                .fill(Color(.systemGray6))
                .frame(height: 1.5)
        }
    }

    // "26. 05. 08" 형식 (yy. MM. dd). 셀에서만 쓰는 짧은 표기.
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yy. MM. dd"
        f.timeZone = TimeZone(identifier: "ko-KR")
        return f
    }()

    private static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        SearchView()
            .modelContainer(PersistenceController.shared)
    }
}
