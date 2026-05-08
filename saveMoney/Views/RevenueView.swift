import SwiftUI
import SwiftData

struct RevenueView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var swiftUIDismiss

    @Query(filter: #Predicate<FinDataEntity> { $0.isRevenue == true },
           sort: \FinDataEntity.when, order: .reverse)
    private var allRevenues: [FinDataEntity]

    let initialStart: Date
    let initialEnd: Date

    @State private var start: Date
    @State private var end: Date
    @State private var navTitle: String = ""
    @State private var showDateSelector: Bool = false
    @State private var addMode: AddFinView.Mode?

    init(start: Date, end: Date) {
        self.initialStart = start
        self.initialEnd = end
        self._start = State(initialValue: start)
        self._end = State(initialValue: end)
    }

    private var filtered: [FinDataEntity] {
        allRevenues.filter { $0.when >= start && $0.when <= end }
    }

    private var totalAmount: Int {
        filtered.reduce(0) { $0 + $1.how }
    }

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = proxy.size.width * 0.9

            ZStack {
                // 배경 (backgroundColor asset — 라이트/다크 모드 대응)
                Color("backgroundColor")
                    .ignoresSafeArea()
                Image("bg")
                    .resizable()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 네비게이션 바 영역 (상단 safe area 포함)
                    Color.clear
                        .frame(height: proxy.safeAreaInsets.top + 44)

                    // 수입 리스트
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // 헤더 카드
                            headerCard(cardWidth: cardWidth)
                                .padding(.bottom, 0)

                            ForEach(filtered) { item in
                                itemCell(item: item, cardWidth: cardWidth)
                            }
                        }
                        .padding(.bottom, 120)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 상단 네비게이션 바 오버레이
                VStack(spacing: 0) {
                    navBar
                    Spacer()
                }

                // 하단 버튼 두 개
                VStack {
                    Spacer()
                    HStack {
                        // 왼쪽: dismiss (애니메이션 없이 → 화면 전환처럼 보임)
                        Button {
                            UIApplication.shared.connectedScenes
                                .compactMap { $0 as? UIWindowScene }
                                .first?.windows.first?.rootViewController?
                                .presentedViewController?.dismiss(animated: false)
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 60, height: 60)
                                .background(Color("customLabel"))
                                .foregroundStyle(Color("backgroundColor"))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 24)

                        Spacer()

                        // 오른쪽: 수입 추가
                        Button {
                            addMode = .new
                        } label: {
                            Image(systemName: "highlighter")
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 60, height: 60)
                                .background(Color("pinColor"))
                                .foregroundStyle(Color("backgroundColor"))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 24)
                    }
                    .padding(.bottom, proxy.safeAreaInsets.bottom + 30)
                    .ignoresSafeArea(.keyboard)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: addMode != nil) { _, showing in
            guard showing, let mode = addMode else { return }
            let view = AddFinView(source: .revenue, mode: mode)
                .modelContainer(PersistenceController.shared)
            let host = UIHostingController(rootView: view)
            host.modalPresentationStyle = .overFullScreen
            host.view.backgroundColor = .clear
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first?.rootViewController?
                .presentedViewController?.present(host, animated: false) {
                    addMode = nil
                }
        }
        .sheet(isPresented: $showDateSelector) {
            MonthSelectorSheet(
                onSelect: { newStart, newEnd, label in
                    start = newStart
                    end = newEnd
                    navTitle = label
                    showDateSelector = false
                },
                onReset: {
                    start = initialStart
                    end = initialEnd
                    navTitle = defaultNavTitle()
                    showDateSelector = false
                }
            )
            .presentationDetents([.fraction(0.4)])
        }
        .onAppear {
            navTitle = defaultNavTitle()
        }
    }

    private var navBar: some View {
        ZStack {
            Color.clear
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .overlay {
            Button {
                showDateSelector = true
            } label: {
                Text(navTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color("customLabel"))
            }
        }
        .padding(.top, UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 44)
    }

    private func headerCard(cardWidth: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Image("tape1")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 30)
                .zIndex(1)

            HStack {
                Text("이번 달 수입은")
                    .font(.custom("PretendardVariable-SemiBold", size: 18))
                    .foregroundStyle(Color("customLabel"))
                Spacer()
                Text("₩ \(totalAmount.toDecimal())")
                    .font(.custom("PretendardVariable-ExtraBold", size: 18))
                    .foregroundStyle(Color("customLabel"))
            }
            .padding(.horizontal, 12)
            .frame(width: cardWidth, height: 72)
            .background(Color("memoPaperColor"))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 5)
            .padding(.top, 15)
        }
        .frame(width: cardWidth)
        .frame(maxWidth: .infinity)
    }

    private func defaultNavTitle() -> String {
        initialStart.toString(false) + " ~ " + initialEnd.toString(false)
    }

    private func itemCell(item: FinDataEntity, cardWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Button {
                deleteItem(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(uiColor: .label).opacity(0.24))
                    .frame(width: 24)
            }
            .padding(.leading, 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.when.toString(false))
                    .font(.custom("PretendardVariable-Medium", size: 12))
                    .foregroundStyle(Color("customLabel"))
                Text(item.towhat)
                    .font(.custom("PretendardVariable-Medium", size: 14))
                    .foregroundStyle(Color("customLabel"))
                    .lineLimit(1)
            }
            .padding(.leading, 10)

            Spacer()

            Text("+ \(item.how.toDecimal())")
                .font(.custom("PretendardVariable-SemiBold", size: 16))
                .foregroundStyle(Color("customLabel"))
                .padding(.trailing, 20)
        }
        .frame(width: cardWidth, height: 72)
        .background(Color("memoPaperColor"))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 5)
        .frame(maxWidth: .infinity)
        .onLongPressGesture {
            addMode = .edit(item)
        }
    }

    private func deleteItem(_ item: FinDataEntity) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}

// MARK: - Supporting Types

// fullScreenCover의 배경을 투명하게 만들기 위한 UIKit 브리지
struct ClearBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct AddFinSheet: Identifiable {
    let mode: AddFinView.Mode
    var id: String {
        switch mode {
        case .new: return "new"
        case .edit(let item): return "edit-\(item.externalID)"
        }
    }
}

struct MonthSelectorSheet: View {
    let onSelect: (Date, Date, String) -> Void
    let onReset: () -> Void

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())

    private var years: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array(2021...current)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("년", selection: $selectedYear) {
                    ForEach(years, id: \.self) { year in
                        Text("\(year)년").tag(year)
                    }
                }
                .pickerStyle(.wheel)

                Picker("월", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text("\(month)월").tag(month)
                    }
                }
                .pickerStyle(.wheel)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset", action: onReset)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("설정") {
                        let comps = DateComponents(year: selectedYear, month: selectedMonth)
                        guard let date = Calendar.current.date(from: comps) else { return }
                        let label = "🗓 \(selectedYear)년 \(selectedMonth)월"
                        onSelect(date.startOfThisMonth, date.endOfThisMonth, label)
                    }
                }
            }
        }
    }
}

#Preview {
    RevenueView(start: Date().startOfThisMonth, end: Date().endOfThisMonth)
        .modelContainer(PersistenceController.shared)
}
