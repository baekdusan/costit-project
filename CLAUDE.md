# CostIt (코스트잇) - Claude Code Context

## Project Overview
iOS 개인 가계부 앱. 지출/수입 관리, 캘린더 조회, 고정 지출 알림, 홈 화면 위젯 제공.

**UIKit/Storyboard → SwiftUI 전환 완료** (모든 화면 SwiftUI, legacy VC·Main.storyboard 삭제됨. UIKit 잔여는 `struct.swift`의 데이터 모델/확장과 위젯 호스팅뿐). 데이터는 **UserDefaults → SwiftData (CloudKit 동기화)** 마이그레이션 완료.

## Tech Stack
- Swift / SwiftUI (앱 루트가 SwiftUI MainView. `struct.swift`의 모델·확장만 UIKit 시절 코드로 잔존)
- WidgetKit (SwiftUI) — SwiftData 직접 쿼리
- SwiftData + CloudKit (App Group: `group.costit`, CloudKit 컨테이너: `iCloud.kr.co.saveMoney`)
- **CocoaPods 의존성 없음** (FSCalendar 제거 완료, 자체 `MonthCalendarGrid` 사용 → `.xcodeproj` 직접 빌드, `.xcworkspace` 없음)
- iOS 17.0+ 타겟

## Build
```bash
xcodebuild -project saveMoney.xcodeproj -scheme saveMoney \
  -destination 'platform=iOS Simulator,name=iPhone 17e,OS=26.5' build
```

## Key Files

### SwiftData / Persistence
| 파일 | 역할 |
|------|------|
| `saveMoney/Persistence/Models.swift` | `@Model` 4종 (`FinDataEntity`, `FixedExpenditureEntity`, `ProfileEntity`, `SalaryPeriodEntity`) |
| `saveMoney/Persistence/PersistenceController.swift` | App Group + CloudKit private 컨테이너 (`.private("iCloud.kr.co.saveMoney")`) |
| `saveMoney/Persistence/LegacyMigration.swift` | UserDefaults → SwiftData 멱등 이전. fingerprint(SHA256) 기반 — 레거시 데이터가 바뀌면 재실행, 레코드 단위 dedup(externalID+내용)으로 중복 방지 (과거 1회성 `v1` bool 플래그는 구버전 복귀 후 추가된 데이터를 영영 못 옮기는 버그가 있어 교체). 앱 첫 실행 시 `AppDelegate.didFinishLaunching`에서 자동 실행 |

### SwiftUI Views (이미 전환된 화면)
| 파일 | 역할 |
|------|------|
| `saveMoney/Views/FirstOpenView.swift` | 온보딩 / 프로필 수정 (MainView에서 push) |
| `saveMoney/Views/SearchView.swift` | 검색 (CalendarView에서 push). SwiftData `@Query` 직접 사용 |
| `saveMoney/Views/SearchBarRepresentable.swift` | UISearchBar UIViewRepresentable 래퍼 |
| `saveMoney/Views/RevenueView.swift` | 수입 관리 (MainView에서 fullScreenCover) |
| `saveMoney/Views/AddFinView.swift` | 지출/수입 추가/수정 통합 화면 (overFullScreen으로 띄움, 카드 UI) |
| `saveMoney/Views/FixedExpenditureView.swift` | 고정 지출 관리 + 푸시 알림 (CalendarView에서 fullScreenCover) |
| `saveMoney/Views/CalendarView.swift` | 캘린더 (MainView에서 fullScreenCover). 자체 `MonthCalendarGrid` 사용. SearchView push / FixedExpenditureView cover 연결 |
| `saveMoney/Views/MainView.swift` | 메인 대시보드 — 앱 루트 (SceneDelegate에서 UIHostingController로 설정). 잔액 헤더, 메모지 그리드, 년/월 필터, 온보딩(FirstOpenView push) |

### UIKit 잔여
| 파일 | 역할 |
|------|------|
| `saveMoney/struct.swift` | 데이터 모델 (`finData`, `FixedExpenditure`, `profile`, `salaryDate`) + Date/String/Int 확장. SwiftUI 화면들도 이 모델/확장을 사용 |
| `saveMoney/AppDelegate.swift` / `SceneDelegate.swift` | 앱 부팅 + LegacyMigration 트리거 + SwiftUI MainView 루트 설정 |
| `widget/widget.swift` | 홈 화면 위젯. SwiftData 직접 쿼리 (CloudKit 동기화 데이터 반영) |

## Data Model

### SwiftData (현재 source of truth)
- `FinDataEntity`: `when, towhat, how, isRevenue, externalID` — 지출/수입 구분은 `isRevenue`
- `FixedExpenditureEntity`: `externalID, day, towhat, how`
- `ProfileEntity`: `slot, nickName, outLay, period`
- `SalaryPeriodEntity`: `slot, startDate, endDate`
- 모든 프로퍼티 default 값 보유 (CloudKit 호환 조건)

### UserDefaults (레거시 — 읽기 전용)
- 키: `finlist`, `rfinList`, `fixedFinList`, `profile`, `salarydata` — 구버전이 남긴 데이터. LegacyMigration이 읽어 SwiftData로 이전(멱등). 앱은 더 이상 여기에 쓰지 않음 (`firstOpen` 플래그만 사용)

## Architecture Notes
- **앱 루트**: SceneDelegate가 SwiftUI `MainView`를 `UIHostingController`로 감싸 루트로 설정 (storyboard 미사용)
- **데이터 소스**: SwiftData 단일 source of truth. 모든 SwiftUI 화면이 `@Query` / `ModelContext` 직접 사용
- **위젯**: `PersistenceController.shared` 컨테이너에서 직접 fetch (App Group으로 앱과 공유)
- **AddFinView 저장**: environment `\.modelContext` 주입 손실 회피 위해 `ModelContext(PersistenceController.shared)` 직접 생성해서 저장
- **AddFinView dismiss**: SwiftUI dismiss + 50ms 후 UIKit topMostPresentedViewController dismiss 폴백

## Refactoring Status

### Phase 1: Force Unwrap / Crash 방지 — DONE (b75081c)

### Phase 2: 데이터 레이어 안전화 — DONE
- SwiftData 도입 + LegacyMigration으로 UserDefaults → SwiftData 멱등 이전
- CloudKit 동기화 (`iCloud.kr.co.saveMoney` private DB)
- App Group `group.costit`로 앱/위젯 컨테이너 공유

### Phase 3: SwiftUI 점진 전환 — DONE
- FirstOpenView, SearchView, RevenueView, AddFinView, FixedExpenditureView, CalendarView (자체 MonthCalendarGrid로 FSCalendar 의존 제거), MainView (루트 교체)
- **모든 화면 전환 완료.** UserDefaults에는 더 이상 데이터를 기록하지 않음 ("firstOpen" 플래그만 사용). 위젯 리로드는 AddFinView/RevenueView/MainView의 저장·삭제 시점에 수행
- 기존 사용자 데이터 마이그레이션 검증 완료 (2026-06-13): UserDefaults→SwiftData 무손실·멱등 확인

### Phase 4: 정리 작업 — IN PROGRESS
- **DONE (Step 1, 2026-06-13)**: legacy ViewController 8종 + `Main.storyboard` + `Repositories.swift` 삭제. `FixedExpenditureView`의 죽은 `syncToUIKit()`/`toMainVC` post 제거. 빌드 통과
- **DONE (Step 2, 2026-06-13)**: FSCalendar pod deintegrate + Podfile/`Podfile.lock`/`saveMoney.xcworkspace` 삭제 → `.xcodeproj` 직접 빌드 전환. 캘린더 화면 런타임 검증 완료
- **TODO — Step 3: 네이밍 컨벤션 정리** (다음 세션 착수 가능. 빌드 검증: `xcodebuild -project saveMoney.xcodeproj -scheme saveMoney -destination 'platform=iOS Simulator,name=iPhone 17e,OS=26.5' build`)
  - **`finData` struct는 dead code** — legacy VC 삭제 후 사용처 0 (struct.swift 정의만). 먼저 `grep -rn '\bfinData\b'`로 재확인 후 **삭제**(rename 불필요)
  - `FixedExpenditure`(struct) → `FixedExpenditureItem` 등으로 rename. **주의: SwiftData의 `FixedExpenditureEntity`와 혼동 금지.** 영향: `struct.swift`(정의 + `UNUserNotificationCenter.addNotificationRequest` extension), `FixedExpenditureView.swift`(알림 페이로드)
  - `profile` → `Profile`, `salaryDate` → `SalaryDate`. 영향: `struct.swift`, `MainView.swift`(`setSalaryDate` 반환형), `FirstOpenView.swift`, `widget/widget.swift`
  - **CodingKeys backward 호환 불필요**: 앱은 더 이상 이 타입들을 UserDefaults에 인코딩하지 않음 (저장은 SwiftData Entity, 디코딩은 LegacyMigration의 자체 `LegacyFin`/`LegacyFixed`/`LegacyProfile`/`LegacySalary`가 전담). 따라서 단순 rename으로 충분
- **TODO — Xcode Cloud 연동 마무리** (App Store Connect, 사용자 직접 작업): main 브랜치 → 아카이브 워크플로 생성됨 (2026-06-04). 이제 Pod이 제거됐으므로 워크플로 설정에서 "프로젝트 또는 워크스페이스"를 `saveMoney.xcworkspace` → `saveMoney.xcodeproj`로 변경하고, "배포 준비"를 없음 → TestFlight/App Store Connect로 설정해야 동작
- **TODO — 실기기/UI 직접 테스트** (아래 "디자인/검증 도구"의 체크리스트)

### 디자인/검증 도구
- SceneDelegate DEBUG 블록: `SIMCTL_CHILD_SEED_DEMO_DATA=1`(데모 데이터 주입), `SIMCTL_CHILD_SHOW_SCREEN=calendar|fixed|revenue`(특정 화면 루트로). Xcode Preview는 `PreviewSampleData.container`(in-memory 시드) 사용
- 남은 UI 직접 테스트 체크리스트: 지출 추가/수정(길게 누르기)/삭제, 수입 화면, 고정 지출+푸시 알림, 검색, 온보딩→메인 복귀, 프로필 수정→기간 갱신, 년/월 필터+Reset, 위젯 갱신, CloudKit 동기화, 다크 모드

## Known Issues / Notes
- AddFinView edit 모드는 `externalID`로 fetch 후 수정 (context mismatch 회피)
- SourceKit 인덱서가 종종 cross-file symbol을 못 찾는 경우가 있음 (실제 빌드는 정상)

## Conventions
- 커밋 메시지: 한국어 본문 허용, prefix는 영어 (refactor:, fix:, feat:)
- 빌드 대상: iPhone 17e Simulator (OS 26.5) / 실기기 iOS 17+
- 사용자 언어: 한국어
