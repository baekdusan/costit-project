import SwiftUI
import SwiftData
import WidgetKit

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
    @State private var customTitle: String?   // 월 선택 시 라벨 (nil이면 기본 기간 표시)

    // @State + onAppear 초기화 패턴은 UIHostingController로 직접 present될 때
    // onAppear가 발화하지 않아 빈 타이틀이 되는 문제가 있어 computed로 유지한다.
    private var navTitle: String {
        customTitle ?? (initialStart.toString(false) + " ~ " + initialEnd.toString(false))
    }

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

                    // 수입 리스트 — 헤더와 내역 전체가 한 장의 종이(단일 배경 + 단일 그림자)로 보이게
                    ScrollView {
                        ZStack(alignment: .top) {
                            Image("tape1")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 30)
                                .zIndex(1)

                            VStack(spacing: 0) {
                                headerRow(cardWidth: cardWidth)

                                ForEach(filtered) { item in
                                    itemCell(item: item, cardWidth: cardWidth)
                                }
                            }
                            .frame(width: cardWidth)
                            .background(Color("memoPaperColor"))
                            .compositingGroup()
                            .shadow(color: .black.opacity(0.08), radius: 6, y: 5)
                            .padding(.top, 15)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 120)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 상단 네비게이션 바 오버레이
                VStack(spacing: 0) {
                    navBar(topInset: proxy.safeAreaInsets.top)
                    Spacer()
                }

                // 하단 버튼 두 개
                VStack {
                    Spacer()
                    HStack {
                        // 왼쪽: dismiss (애니메이션 없이 → 화면 전환처럼 보임)
                        Button {
                            UIApplication.shared.appRootViewController?
                                .presentedViewController?.dismiss(animated: false)
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 60, height: 60)
                                .background(Color("pinColor"))
                                .foregroundStyle(Color("backgroundColor"))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 30)

                        Spacer()

                        // 오른쪽: 수입 추가
                        Button {
                            presentAddFin(mode: .new)
                        } label: {
                            Image(systemName: "highlighter")
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 60, height: 60)
                                .background(Color("pinColor"))
                                .foregroundStyle(Color("backgroundColor"))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 30)
                    }
                    .padding(.bottom, proxy.safeAreaInsets.bottom + 30)
                    .ignoresSafeArea(.keyboard)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea(.keyboard)
    }

    // 날짜 선택 시트를 UIKit으로 직접 present.
    // (RevenueView 자체가 UIKit으로 present된 호스트라, 그 위에 SwiftUI .sheet를 띄우면
    //  시트 안 버튼 탭이 전달되지 않는 문제가 있음 — AddFinView와 같은 패턴으로 회피)
    private func presentMonthSelector() {
        guard let root = UIApplication.shared.appRootViewController else { return }
        var presenter = root
        while let next = presenter.presentedViewController { presenter = next }
        guard !presenter.isBeingDismissed else { return }

        func dismissSheet() {
            var top: UIViewController = root
            while let next = top.presentedViewController { top = next }
            top.dismiss(animated: true)
        }

        let host = UIHostingController(rootView: MonthSelectorSheet(
            onSelect: { newStart, newEnd, label in
                start = newStart
                end = newEnd
                customTitle = label
                dismissSheet()
            },
            onReset: {
                start = initialStart
                end = initialEnd
                customTitle = nil
                dismissSheet()
            }
        ))
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.custom { $0.maximumDetentValue * 0.45 }]
            sheet.prefersGrabberVisible = false
        }
        presenter.present(host, animated: true)
    }

    // ⚠️ body 안에서 UIApplication.shared.appKeyWindow의 safe area를 직접 읽으면
    // "body → 윈도우 레이아웃 → 뷰 트리" 의존성 순환(AttributeGraph cycle)이 생겨
    // 이 서브트리의 상태 업데이트가 통째로 무시됨 (월 선택해도 타이틀·리스트 미갱신 버그의 원인).
    // GeometryReader proxy의 safe area를 파라미터로 받아 사용한다.
    private func navBar(topInset: CGFloat) -> some View {
        ZStack {
            Color.clear
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .overlay {
            Button {
                presentMonthSelector()
            } label: {
                Text(navTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color("customLabel"))
            }
        }
        .padding(.top, topInset)
    }

    // 수입 추가/수정 화면을 UIKit으로 직접 present.
    // (이전의 onChange(of: addMode != nil) 패턴은 편집→편집 연속 진입 시 발화하지 않는 버그가 있었음)
    private func presentAddFin(mode: AddFinView.Mode) {
        guard let root = UIApplication.shared.appRootViewController else { return }
        // 최상단 VC에서 present (이미 다른 모달이 진행 중이면 그 위에 얹지 않고 무시됨 방지 +
        // RevenueView가 루트로 뜨는 DEBUG 모드에서도 동작)
        var presenter = root
        while let next = presenter.presentedViewController { presenter = next }
        guard !presenter.isBeingDismissed else { return }   // dismiss 진행 중인 VC 위에는 present하지 않음
        let view = AddFinView(source: .revenue, mode: mode)
            .modelContainer(PersistenceController.shared)
        let host = UIHostingController(rootView: view)
        host.modalPresentationStyle = .overFullScreen
        host.view.backgroundColor = .clear
        presenter.present(host, animated: false)
    }

    private func headerRow(cardWidth: CGFloat) -> some View {
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
        .contentShape(Rectangle())
        .onLongPressGesture {
            presentAddFin(mode: .edit(item))
        }
    }

    private func deleteItem(_ item: FinDataEntity) {
        modelContext.delete(item)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
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
        // 디바이스 시계가 2021 이전으로 설정돼 있어도 빈 Range 크래시가 나지 않도록 가드
        let current = Calendar.current.component(.year, from: Date())
        return Array(2021...max(2021, current))
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
                    guard let date = Calendar.current.date(from: comps) else { return }
                    let label = "🗓 \(selectedYear)년 \(selectedMonth)월"
                    onSelect(date.startOfThisMonth, date.endOfThisMonth, label)
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .tint(Color("customLabel"))
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

#Preview {
    RevenueView(start: Date().startOfThisMonth, end: Date().endOfThisMonth)
        .modelContainer(PreviewSampleData.container)
}
