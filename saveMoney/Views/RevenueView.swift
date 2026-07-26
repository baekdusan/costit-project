import SwiftUI
import SwiftData

struct RevenueView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<FinDataEntity> { $0.isRevenue == true },
           sort: \FinDataEntity.when, order: .reverse)
    private var allRevenues: [FinDataEntity]

    let initialStart: Date
    let initialEnd: Date

    @State private var start: Date
    @State private var end: Date
    @State private var customTitle: String?   // 월 선택 시 라벨 (nil이면 기본 기간 표시)
    @State private var deleteTarget: FinDataEntity?   // 삭제 확인 알럿 대상 (MainView와 동일 패턴)

    // @State + onAppear 초기화 패턴은 UIHostingController로 직접 present될 때
    // onAppear가 발화하지 않아 빈 타이틀이 되는 문제가 있어 computed로 유지한다.
    private var navTitle: String {
        customTitle ?? (initialStart.toString() + " ~ " + initialEnd.toString())
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
                Color(.background)
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
                            .background(Color(.memoPaper))
                            .compositingGroup()
                            .paperShadow(y: 5)
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
                        CircleActionButton(systemName: "arrow.left.arrow.right", background: Color(.pin)) {
                            UIApplication.shared.appRootViewController?
                                .presentedViewController?.dismiss(animated: false)
                        }
                        .padding(.leading, 30)

                        Spacer()

                        // 오른쪽: 수입 추가
                        CircleActionButton(systemName: "highlighter", background: Color(.pin)) {
                            presentAddFin(source: .revenue, mode: .new)
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
        .deleteConfirmationAlert(item: $deleteTarget, message: "해당 수입 내역을 삭제해요.") {
            deleteItem($0)
        }
    }

    // MARK: - 화면 전환 (UIKit present)

    // 날짜 선택 시트를 UIKit으로 직접 present.
    // (RevenueView 자체가 UIKit으로 present된 호스트라, 그 위에 SwiftUI .sheet를 띄우면
    //  시트 안 버튼 탭이 전달되지 않는 문제가 있음 — AddFinView와 같은 패턴으로 회피)
    private func presentMonthSelector() {
        guard let root = UIApplication.shared.appRootViewController else { return }
        let presenter = root.topMostPresentedViewController
        guard !presenter.isBeingDismissed else { return }

        func dismissSheet() {
            root.topMostPresentedViewController.dismiss(animated: true)
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
        )
        // MonthSelectorSheet는 @Query로 저장된 내역의 연도 범위를 읽는다.
        // 새 UIHostingController는 environment를 상속하지 않으므로 컨테이너를 직접 주입해야 한다
        // (없으면 @Query가 활성 컨테이너를 찾지 못해 크래시).
        .modelContainer(PersistenceController.shared)
        .dynamicTypeSize(.large))
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
                    .foregroundStyle(Color(.customLabel))
            }
        }
        .padding(.top, topInset)
    }

    // MARK: - 리스트 셀

    private func headerRow(cardWidth: CGFloat) -> some View {
        HStack {
            Text("이번 달 수입은")
                .font(.pretendard(.semiBold, size: 18))
                .foregroundStyle(.primary)
            Spacer()
            Text("₩ \(totalAmount.toDecimal())")
                .font(.pretendard(.extraBold, size: 18))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .frame(width: cardWidth, height: 72)
    }

    private func itemCell(item: FinDataEntity, cardWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Button {
                deleteTarget = item
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(uiColor: .label).opacity(0.24))
                    .frame(width: 24)
            }
            .padding(.leading, 10)

            // 스토리보드 레이아웃: towhat과 금액이 셀 세로 중앙에서 수평 정렬, 날짜는 towhat 위 4pt.
            // 색: 날짜만 customLabel(회색조), towhat·금액은 기본 label 색
            Text(item.towhat)
                .font(.pretendard(.medium, size: 14))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .overlay(alignment: .topLeading) {
                    Text(item.when.toString())
                        .font(.pretendard(.medium, size: 12))
                        .foregroundStyle(Color(.customLabel))
                        .fixedSize()
                        .offset(y: -18)   // 날짜 높이(≈14pt) + 간격 4pt만큼 위로
                }
                .padding(.leading, 10)

            Spacer()

            Text("+ \(item.how.toDecimal())")
                .font(.pretendard(.semiBold, size: 16))
                .foregroundStyle(.primary)
                .padding(.trailing, 20)
        }
        .frame(width: cardWidth, height: 72)
        .contentShape(Rectangle())
        .onLongPressGesture {
            presentAddFin(source: .revenue, mode: .edit(.init(item)))
        }
    }

    // MARK: - 데이터 조작

    private func deleteItem(_ item: FinDataEntity) {
        PersistenceController.delete(item, in: modelContext)
    }
}

// MARK: - Supporting Types

struct MonthSelectorSheet: View {
    let onSelect: (Date, Date, String) -> Void
    let onReset: () -> Void

    // 실제로 저장된 내역의 연도 범위를 함께 보여준다 — 목록에 없는 연도는 조회 자체가 불가능해
    // "저장은 됐는데 어디서도 볼 수 없는" 데이터가 생긴다 (입력 화면의 DatePicker에는 연도 제한이 없다)
    @Query(sort: \FinDataEntity.when) private var allFin: [FinDataEntity]

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
        let stored = allFin.map { calendar.component(.year, from: $0.when) }
        // 디바이스 시계가 2021 이전으로 설정돼 있어도 빈 Range 크래시가 나지 않도록 가드
        let lower = min(2021, stored.min() ?? 2021)
        let upper = max(current, stored.max() ?? current)
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

#Preview {
    RevenueView(start: Date().startOfThisMonth, end: Date().endOfThisMonth)
        .modelContainer(PreviewSampleData.container)
}
