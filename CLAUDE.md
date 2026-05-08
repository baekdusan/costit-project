# CostIt (코스트잇) - Claude Code Context

## Project Overview
iOS 개인 가계부 앱. 지출/수입 관리, 캘린더 조회, 고정 지출 알림, 홈 화면 위젯 제공.

현재 **UIKit/Storyboard → SwiftUI 점진 전환 중**, 데이터는 **UserDefaults → SwiftData (CloudKit 동기화)** 마이그레이션 완료.

## Tech Stack
- Swift / UIKit + SwiftUI 혼용 (UIHostingController로 화면 단위 점진 전환)
- WidgetKit (SwiftUI) — SwiftData 직접 쿼리
- SwiftData + CloudKit (App Group: `group.costit`, CloudKit 컨테이너: `iCloud.kr.co.saveMoney`)
- FSCalendar (CocoaPods, calendarVC에서만 사용 — 향후 제거 예정)
- iOS 17.0+ 타겟

## Build
```bash
xcodebuild -workspace saveMoney.xcworkspace -scheme saveMoney \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build
```

## Key Files

### SwiftData / Persistence
| 파일 | 역할 |
|------|------|
| `saveMoney/Persistence/Models.swift` | `@Model` 4종 (`FinDataEntity`, `FixedExpenditureEntity`, `ProfileEntity`, `SalaryPeriodEntity`) |
| `saveMoney/Persistence/PersistenceController.swift` | App Group + CloudKit private 컨테이너 (`.private("iCloud.kr.co.saveMoney")`) |
| `saveMoney/Persistence/LegacyMigration.swift` | UserDefaults → SwiftData 1회 멱등 이전 (`migration.userdefaults_to_swiftdata.v1` 플래그) |
| `saveMoney/Persistence/Repositories.swift` | UIKit 코드용 어댑터 — 점진 전환 기간 동안만 사용 |

### SwiftUI Views (이미 전환된 화면)
| 파일 | 역할 |
|------|------|
| `saveMoney/Views/FirstOpenView.swift` | 온보딩 / 프로필 수정 (mainVC가 UIHostingController로 호출) |
| `saveMoney/Views/SearchView.swift` | 검색 (calendarVC에서 호출). SwiftData `@Query` 직접 사용 |
| `saveMoney/Views/SearchBarRepresentable.swift` | UISearchBar UIViewRepresentable 래퍼 |
| `saveMoney/Views/RevenueView.swift` | 수입 관리 (mainVC `revenueButtonTapped:`에서 fullScreen present) |
| `saveMoney/Views/AddFinView.swift` | 지출/수입 추가/수정 통합 화면 (overFullScreen으로 띄움, 카드 UI) |

### UIKit (아직 남아있음)
| 파일 | 역할 |
|------|------|
| `saveMoney/struct.swift` | 데이터 모델 (`finData`, `FixedExpenditure`, `profile`, `salaryDate`) + Date/String/Int 확장 |
| `saveMoney/ViewControllers/mainVC.swift` | 메인 대시보드. SwiftData ↔ UserDefaults 양쪽 모두 저장 |
| `saveMoney/ViewControllers/calendarVC.swift` | 캘린더 (FSCalendar) — SwiftUI 전환 + FSCalendar 제거 예정 |
| `saveMoney/ViewControllers/fixedExpenditureVC.swift` | 고정 지출 + 푸시 알림 — SwiftUI 전환 예정 |
| `saveMoney/ViewControllers/addFinVC.swift` | (legacy, 더 이상 호출 안 됨, AddFinView로 대체) |
| `saveMoney/ViewControllers/revenueVC.swift` | (legacy, 더 이상 호출 안 됨, RevenueView로 대체) |
| `saveMoney/ViewControllers/searchVC.swift` | (legacy, 더 이상 호출 안 됨, SearchView로 대체) |
| `saveMoney/ViewControllers/firstOpenVC.swift` | (legacy, 더 이상 호출 안 됨, FirstOpenView로 대체) |
| `widget/widget.swift` | 홈 화면 위젯. SwiftData 직접 쿼리 (CloudKit 동기화 데이터 반영) |

## Data Model

### SwiftData (현재 source of truth)
- `FinDataEntity`: `when, towhat, how, isRevenue, externalID` — 지출/수입 구분은 `isRevenue`
- `FixedExpenditureEntity`: `externalID, day, towhat, how`
- `ProfileEntity`: `slot, nickName, outLay, period`
- `SalaryPeriodEntity`: `slot, startDate, endDate`
- 모든 프로퍼티 default 값 보유 (CloudKit 호환 조건)

### UserDefaults (호환성 유지용 — 점진 전환 중 fallback)
- 키: `finlist`, `rfinList`, `fixedFinList`, `profile`, `salarydata`
- mainVC가 didSet에서 UserDefaults + SwiftData 양쪽에 저장 (FinRepository 통해)

## Architecture Notes
- **점진 전환 전략**: UIKit ViewController가 SwiftUI 화면을 `UIHostingController`로 띄움
- **데이터 일관성**: mainVC는 didSet에서 UserDefaults + SwiftData 동시 기록. SwiftUI 화면은 SwiftData만 사용. UIKit으로 돌아올 때 mainVC `viewWillAppear`에서 SwiftData 기준 재로드
- **위젯**: `PersistenceController.shared` 컨테이너에서 직접 fetch (App Group으로 앱과 공유)
- **AddFinView 저장**: environment `\.modelContext` 주입 손실 회피 위해 `ModelContext(PersistenceController.shared)` 직접 생성해서 저장
- **AddFinView dismiss**: SwiftUI dismiss + 50ms 후 UIKit topMostPresentedViewController dismiss 폴백
- **fixedExpenditureVC → mainVC 전달**: NotificationCenter (`toMainVC`)

## Refactoring Status

### Phase 1: Force Unwrap / Crash 방지 — DONE (b75081c)

### Phase 2: 데이터 레이어 안전화 — DONE
- SwiftData 도입 + LegacyMigration으로 UserDefaults → SwiftData 멱등 이전
- CloudKit 동기화 (`iCloud.kr.co.saveMoney` private DB)
- App Group `group.costit`로 앱/위젯 컨테이너 공유

### Phase 3: SwiftUI 점진 전환 — IN PROGRESS
- DONE: FirstOpenView, SearchView, RevenueView, AddFinView
- TODO: FixedExpenditureView, CalendarView (FSCalendar 제거 동반), MainView (마지막)

### Phase 4: 정리 작업 — TODO
- legacy ViewController 파일 삭제 (`addFinVC.swift`, `revenueVC.swift`, `searchVC.swift`, `firstOpenVC.swift`) — SwiftUI 안정화 후
- Pod deintegrate + `.xcworkspace` → `.xcodeproj` 전환 (FSCalendar 제거 후)
- UserDefaults 의존 제거 (mainVC가 SwiftData만 쓰도록 정리)
- 네이밍 컨벤션 정리 (`finData` → `FinData` 등) — Codable CodingKeys로 backward 호환

## Known Issues / Notes
- mainVC가 SwiftData와 UserDefaults에 양쪽 저장 — 데이터 정합성 위험. SwiftUI 전환 완료 후 UserDefaults 제거
- AddFinView edit 모드는 `externalID`로 fetch 후 수정 (context mismatch 회피)
- SourceKit 인덱서가 종종 cross-file symbol을 못 찾는 경우가 있음 (실제 빌드는 정상)

## Conventions
- 커밋 메시지: 한국어 본문 허용, prefix는 영어 (refactor:, fix:, feat:)
- 빌드 대상: iPhone 16 Simulator (OS 18.5) / 실기기 iOS 17+
- 사용자 언어: 한국어
