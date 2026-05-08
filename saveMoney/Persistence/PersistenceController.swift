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

        let configuration = ModelConfiguration(
            "CostIt",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .private(cloudContainerID)
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // CloudKit 옵션이 실패하면 로컬 전용으로 폴백 (개발 환경/시뮬레이터 대비)
            let fallback = ModelConfiguration(
                "CostIt",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("ModelContainer 생성 실패: \(error)")
            }
        }
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
