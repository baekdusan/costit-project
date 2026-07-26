import Foundation
import SwiftData
import WidgetKit
import os

// 앱 전역에서 공유하는 SwiftData 컨테이너.
// 위젯과 동일한 App Group 컨테이너에 저장 → 위젯에서도 동일 데이터 접근 가능.
// CloudKit 동기화는 cloudKitDatabase: .private("iCloud.kr.co.saveMoney") 로 활성화.
enum PersistenceController {
    static let appGroupID = "group.costit"
    static let cloudContainerID = "iCloud.kr.co.saveMoney"
    static let storeFileName = "CostIt.store"

    // 영속 스토어를 끝내 열지 못해 in-memory 컨테이너로 폴백했는지 여부.
    // true면 이번 실행에서 저장한 내역이 앱 종료와 함께 사라진다 — 조용히 성공한 척하면
    // 사용자가 계속 입력하다 전부 잃으므로 화면에서 경고해야 한다.
    // (스토어 파일 자체는 건드리지 않으므로 기존 데이터는 다음 정상 실행에서 그대로 돌아온다)
    private(set) static var isEphemeralFallback = false

    static let shared: ModelContainer = {
        let schema = Schema([
            FinDataEntity.self,
            FixedExpenditureEntity.self,
            ProfileEntity.self,
            SalaryPeriodEntity.self
        ])

        let storeURL = Self.storeURL()

        // 순서대로 시도: CloudKit → 로컬 전용 → in-memory.
        // 마지막 in-memory는 절대 실패하지 않는 안전망 — 스토어 파일은 건드리지 않으므로
        // 일시적 오류라면 다음 실행에서 데이터가 그대로 복구된다. (fatalError로 부팅 불능이 최악)
        // 시뮬레이터는 iCloud 계정이 없어 CloudKit mirroring이 134400으로 실패한다.
        // 앱은 폴백으로 버티지만 메모리 제약이 큰 위젯 익스텐션은 이로 인해 크래시하므로
        // 시뮬에선 CloudKit을 끄고 로컬 전용으로 동작시킨다. (실기기/배포는 CloudKit 유지)
        #if targetEnvironment(simulator)
        let candidates: [ModelConfiguration] = [
            ModelConfiguration("CostIt", schema: schema, url: storeURL,
                               cloudKitDatabase: .none),
            ModelConfiguration("CostIt", schema: schema, isStoredInMemoryOnly: true,
                               groupContainer: .none, cloudKitDatabase: .none)
        ]
        #else
        let candidates: [ModelConfiguration] = [
            ModelConfiguration("CostIt", schema: schema, url: storeURL,
                               cloudKitDatabase: .private(cloudContainerID)),
            ModelConfiguration("CostIt", schema: schema, url: storeURL,
                               cloudKitDatabase: .none),
            ModelConfiguration("CostIt", schema: schema, isStoredInMemoryOnly: true,
                               groupContainer: .none, cloudKitDatabase: .none)
        ]
        #endif

        for (index, configuration) in candidates.enumerated() {
            do {
                let container = try ModelContainer(for: schema, configurations: [configuration])
                // 마지막 후보가 in-memory 안전망 — 여기까지 왔다면 저장이 휘발성이다
                if index == candidates.count - 1 {
                    isEphemeralFallback = true
                    print("[PersistenceController] 영속 스토어를 열지 못해 in-memory로 폴백 (이번 실행 데이터는 저장되지 않음)")
                }
                return container
            } catch {
                print("[PersistenceController] 컨테이너 생성 실패, 다음 후보로 폴백: \(error)")
            }
        }
        // in-memory까지 실패하는 경우는 사실상 없음 (스키마 자체 결함뿐)
        fatalError("ModelContainer 생성 불가")
    }()

    private static func storeURL() -> URL {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            return groupURL.appendingPathComponent(storeFileName)
        }
        // App Group을 못 잡는 경우(개발 초기 등) 기본 위치 사용
        return URL.applicationSupportDirectory.appendingPathComponent(storeFileName)
    }
}

// MARK: - 저장 + 위젯 갱신 공통 경로
// 위젯은 FinDataEntity(지출)·ProfileEntity·SalaryPeriodEntity를 표시하므로
// 이들을 바꾼 뒤에는 반드시 타임라인 리로드가 따라와야 한다.
// (FixedExpenditureEntity는 위젯 미표시 — FixedExpenditureView는 일반 save 사용)
extension PersistenceController {
    static let logger = Logger(subsystem: cloudContainerID, category: "persistence")

    // 저장 실패 시에도 기존 try? 흐름과 동일하게 진행하되(위젯 리로드 포함), 로그는 남긴다.
    // 실패한 pending 변경은 rollback하지 않는다 — mainContext는 autosave가 켜져 있어
    // 일시 오류라면 재시도로 데이터가 살아남는 쪽을 택함 (그 사이 위젯과 화면이 잠시 어긋날 수 있음).
    @discardableResult
    static func saveAndRefreshWidgets(_ context: ModelContext) -> Bool {
        var saved = true
        do {
            try context.save()
        } catch {
            logger.error("SwiftData save 실패: \(String(describing: error), privacy: .public)")
            saved = false
        }
        WidgetCenter.shared.reloadAllTimelines()
        return saved
    }

    // 지출/수입 삭제 공통 경로 (MainView/RevenueView 동일 구현 통합).
    // FinDataEntity 전용 — 고정 지출 삭제는 알림 해제가 필요하고 위젯 리로드가 불필요하므로 별도 경로.
    //
    // externalID로 받는 이유: 삭제 확인 알럿이 떠 있는 동안 다른 기기의 삭제가 동기화되면
    // 붙들고 있던 @Model 인스턴스는 무효화되어 속성 접근만으로 크래시한다(AddFinView.EditTarget과 같은 이유).
    // 알럿에는 식별자만 넘기고 확인 시점에 다시 찾는다 — 이미 사라졌으면 할 일이 없다.
    @discardableResult
    static func deleteFin(externalID: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<FinDataEntity>(
            predicate: #Predicate { $0.externalID == externalID }
        )
        // 이미 사라진 항목이면 "삭제됨"과 결과가 같으므로 성공으로 본다
        guard let item = (try? context.fetch(descriptor))?.first, !item.isDeleted else { return true }
        context.delete(item)
        // 저장 실패를 호출부에 전달한다 — 화면에서만 사라지고 다음 실행에 되살아나는 것을 알릴 수 있게
        return saveAndRefreshWidgets(context)
    }
}
