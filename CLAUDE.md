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
| `saveMoney/Persistence/PersistenceController.swift` | App Group + CloudKit private 컨테이너 (`.private("iCloud.kr.co.saveMoney")`). `saveAndRefreshWidgets(_:)`/`delete(_:in:)` — 저장+위젯 리로드 공통 경로 (save 실패는 os.Logger 기록) |
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
| `saveMoney/Views/CalendarView.swift` | 캘린더 (MainView에서 fullScreenCover). 일 단위 집계는 `Date`(그 날 00:00) 키 딕셔너리. SearchView push / FixedExpenditureView cover 연결 |
| `saveMoney/Views/MonthCalendarGrid.swift` | 월 달력 그리드 (FSCalendar 대체). CalendarView에서 분리 |
| `saveMoney/Views/MainView.swift` | 메인 대시보드 — 앱 루트 (SceneDelegate에서 UIHostingController로 설정). 잔액 헤더, 메모지 그리드, 년/월 필터, 온보딩(FirstOpenView push) |
| `saveMoney/Views/Components.swift` | 공용 컴포넌트: `CircleActionButton`, `HairlineDivider`, `paperShadow(y:)`, `deleteConfirmationAlert`, 금액 입력 포맷 `currencyInputFormatted(limit:onParseFailure:)` |
| `saveMoney/Views/UIKitPresentation.swift` | UIKit 프레젠테이션 브리지: `UIApplication.appKeyWindow/appRootViewController`, `topMostPresentedViewController`, 공용 `presentAddFin(source:mode:)` |
| `saveMoney/Theme.swift` | `Font.pretendard(_:size:)` 폰트 토큰 (색상은 asset catalog 자동 생성 심볼 `Color(.customLabel)` 등 직접 사용) |

### 공용 유틸 / 진입점
| 파일 | 역할 |
|------|------|
| `saveMoney/struct.swift` | 값 모델 (`FixedExpenditureItem`, `Profile`, `SalaryDate`+`period(forSalaryDay:)`) + Date 확장(gregorian 고정) + `AppDateFormatters`(포매터 캐시) + `AppKeys`/`LaunchEnvKeys`/`SalaryDay` 상수 + 고정 지출 알림 확장. **앱+위젯 양 타겟 멤버** |
| `saveMoney/AppDelegate.swift` / `SceneDelegate.swift` | 앱 부팅 + LegacyMigration 트리거 + SwiftUI MainView 루트 설정 |
| `widget/widget.swift` | 홈 화면 위젯 (`CostItWidget`). SwiftData 직접 쿼리 (CloudKit 동기화 데이터 반영). kind 문자열 `"widget"`은 배치된 위젯의 영속 식별자 — 변경 금지 |

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
- **데이터 소스**: SwiftData 단일 source of truth. 모든 SwiftUI 화면이 `@Query` / environment `\.modelContext` 사용 (AddFinView 포함 — 과거의 `ModelContext(...)` 직접 생성은 environment로 통일됨)
- **저장 경로**: 지출/수입/프로필 변경은 `PersistenceController.saveAndRefreshWidgets(_:)` 경유 (위젯 리로드 동반). 고정 지출은 위젯 미표시라 일반 `save()` (의도된 비대칭)
- **위젯**: `PersistenceController.shared` 컨테이너에서 직접 fetch (App Group으로 앱과 공유)
- **AddFinView dismiss**: SwiftUI dismiss + 50ms 후 UIKit topMostPresentedViewController dismiss 폴백 (onDismiss 클로저 교체는 시각 회귀 검증 필요로 보류)

### 화면 표시 방식 (경위)
| 경로 | 방식 | 이유 |
|------|------|------|
| MainView → CalendarView | SwiftUI fullScreenCover | 일반 케이스 |
| CalendarView → FixedExpenditureView | SwiftUI fullScreenCover | 일반 케이스 |
| CalendarView → SearchView | NavigationStack push | 일반 케이스 |
| MainView → RevenueView | UIKit present (fullScreen, animated: false) | 즉시 전환 연출 |
| Main/Revenue → AddFinView | UIKit present (overFullScreen, 투명 배경) — 공용 `presentAddFin` | cover는 배경 투명화 불가 + onChange 기반 표시는 편집 연속 진입 미발화 버그 |
| RevenueView → MonthSelectorSheet | UIKit sheet present | UIKit present된 호스트 위 SwiftUI .sheet는 버튼 탭 미전달 버그 |

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
- **DONE (Step 3, 2026-06-14, 브랜치 `refactor/phase4-naming`)**: 네이밍 컨벤션 정리. `finData` dead code 삭제(사용처 0), `FixedExpenditure`(struct)→`FixedExpenditureItem`(SwiftData `FixedExpenditureEntity`와 구분), `profile`→`Profile`, `salaryDate`→`SalaryDate`. CodingKeys 호환 불필요(저장은 SwiftData Entity, 레거시 디코딩은 LegacyMigration의 자체 `Legacy*` 타입)했고 빌드 통과
- **DONE (Step 4 라운드, 2026-07-10, 브랜치 `refactor/phase4-cleanup`)**: 멀티에이전트 분석(56건 검증) 기반 정리 라운드.
  ① dead code 일괄 삭제(struct.swift 확장 5종, ClearBackground/AddFinSheet 등) ② DateFormatter/NumberFormatter 캐시 통일(`AppDateFormatters`) ③ CalendarView 일 단위 집계를 Date 키로 일원화 + MonthCalendarGrid 파일 분리 ④ 저장+위젯 리로드 헬퍼(`saveAndRefreshWidgets`) + AddFinView environment context 통일 ⑤ 급여 기간 로직 `SalaryDate.period` 이동 + 엔티티 fallback(`asProfile`/`asSalaryDate`)/상수(`SalaryDay`/`AppKeys`) 집약 ⑥ Color asset 심볼(59곳)/Font 토큰(25곳) ⑦ 공용 컴포넌트 추출(Components.swift) ⑧ UIKit 브리지 통합(UIKitPresentation.swift) ⑨ 버그 4건 fix: 월급날 당일 지출 누락 / ddayTitle 오표시 / 금액 오버플로 0 저장 / 고정지출 날짜 표시·저장 불일치 ⑩ 위젯 타입 리네임(`CostItWidget`)
- **보류 (수동 시각 검증 필요)**: AddFinView 50ms dismiss 폴백 → onDismiss 클로저 교체, RevenueView 닫기 onClose 명시화, 금액 입력 자릿수 정책 통일(15자리/11자 변종이 의도인지 확인), FinStore 계층 도입
- **TODO — Xcode Cloud 연동 마무리** (App Store Connect, 사용자 직접 작업): main 브랜치 → 아카이브 워크플로 생성됨 (2026-06-04). 이제 Pod이 제거됐으므로 워크플로 설정에서 "프로젝트 또는 워크스페이스"를 `saveMoney.xcworkspace` → `saveMoney.xcodeproj`로 변경하고, "배포 준비"를 없음 → TestFlight/App Store Connect로 설정해야 동작
- **TODO — 실기기/UI 직접 테스트** (아래 "디자인/검증 도구"의 체크리스트)

### 디자인/검증 도구
- SceneDelegate DEBUG 블록: `SIMCTL_CHILD_SEED_DEMO_DATA=1`(데모 데이터 주입), `SIMCTL_CHILD_SHOW_SCREEN=calendar|fixed|revenue`(특정 화면 루트로). Xcode Preview는 `PreviewSampleData.container`(in-memory 시드) 사용
- 남은 UI 직접 테스트 체크리스트: 지출 추가/수정(길게 누르기)/삭제, 수입 화면, 고정 지출+푸시 알림, 검색, 온보딩→메인 복귀, 프로필 수정→기간 갱신, 년/월 필터+Reset, 위젯 갱신, CloudKit 동기화, 다크 모드

## Known Issues / Notes
- AddFinView edit 모드는 `externalID`로 fetch 후 수정 (context mismatch 회피 — 원격 삭제 레이스 시 조용한 no-op + 로그)
- SourceKit 인덱서가 종종 cross-file symbol을 못 찾는 경우가 있음 (실제 빌드는 정상)
- String Catalog 미도입 (한국어 단일 로케일). 정수 보간 `Text`는 LocalizedStringKey 콤마 함정 예방 위해 `Text(verbatim:)` 관례. 다국어 진행 시 developmentRegion(en)↔소스 언어(ko) 불일치도 함께 정리할 것

## Conventions
- 커밋 메시지: 한국어 본문 허용, prefix는 영어 (refactor:, fix:, feat:)
- 빌드 대상: iPhone 17e Simulator (OS 26.5) / 실기기 iOS 17+
- 사용자 언어: 한국어
- 색상은 asset 심볼 `Color(.customLabel)`, UIKit 색은 `Color(uiColor:)`, 커스텀 폰트는 `Font.pretendard(_:size:)`
- 새 Swift 파일 추가 시 pbxproj 수동 등록 필요 (구식 그룹 방식 — 파일시스템 동기화 그룹 아님). struct.swift/Models/Persistence/LegacyMigration은 위젯 타겟에도 등록
