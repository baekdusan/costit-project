import Foundation
import SwiftData

// 앱 전역에서 공유하는 SwiftData 컨테이너.
// 위젯과 동일한 App Group 컨테이너에 저장 → 위젯에서도 동일 데이터 접근 가능.
// CloudKit 동기화는 cloudKitDatabase: .private("iCloud.kr.co.saveMoney") 로 활성화.
enum PersistenceController {
    static let appGroupID = "group.costit"
    static let cloudContainerID = "iCloud.kr.co.saveMoney"
    static let storeFileName = "CostIt.store"

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
        let candidates: [ModelConfiguration] = [
            ModelConfiguration("CostIt", schema: schema, url: storeURL,
                               cloudKitDatabase: .private(cloudContainerID)),
            ModelConfiguration("CostIt", schema: schema, url: storeURL,
                               cloudKitDatabase: .none),
            ModelConfiguration("CostIt", schema: schema, isStoredInMemoryOnly: true,
                               groupContainer: .none, cloudKitDatabase: .none)
        ]

        for configuration in candidates {
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
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
        let docs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(storeFileName)
    }
}
