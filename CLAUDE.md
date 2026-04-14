# CostIt (코스트잇) - Claude Code Context

## Project Overview
iOS 개인 가계부 앱. 지출/수입 관리, 캘린더 조회, 고정 지출 알림, 홈 화면 위젯 제공.

## Tech Stack
- Swift / UIKit (Storyboard 기반 MVC)
- WidgetKit (SwiftUI)
- FSCalendar (CocoaPods, 유일한 외부 의존성)
- iOS 13.0+ 타겟
- 데이터 저장: UserDefaults (PropertyListEncoder/Decoder)

## Build
```bash
xcodebuild -workspace saveMoney.xcworkspace -scheme saveMoney \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build
```

## Key Files
| 파일 | 역할 |
|------|------|
| `saveMoney/struct.swift` | 데이터 모델 (finData, FixedExpenditure, profile, salaryDate) + Date/String/Int 확장 |
| `saveMoney/ViewControllers/mainVC.swift` | 메인 대시보드 (지출 목록, 예산 잔액) |
| `saveMoney/ViewControllers/addFinVC.swift` | 지출/수입 추가/수정 화면 |
| `saveMoney/ViewControllers/calendarVC.swift` | 캘린더 (FSCalendar) |
| `saveMoney/ViewControllers/revenueVC.swift` | 수입 관리 |
| `saveMoney/ViewControllers/fixedExpenditureVC.swift` | 고정 지출 + 푸시 알림 |
| `saveMoney/ViewControllers/searchVC.swift` | 검색 |
| `saveMoney/ViewControllers/firstOpenVC.swift` | 온보딩 / 프로필 수정 |
| `widget/widget.swift` | 홈 화면 위젯 |

## Data Model
- `finData`: `when: Date`, `towhat: String`, `how: Int` - 커스텀 디코더로 기존 IUO 데이터 호환
- `FixedExpenditure`: `id: String`, `day: Int`, `towhat: String`, `how: Int` - 동일
- UserDefaults 키: `finlist`, `rfinList`, `fixedFinList`, `profile`, `salarydata`
- 위젯 데이터: App Group `group.costit`

## Architecture Notes
- 화면 간 데이터 전달: delegate 프로토콜 (sendFinData, shareRevenueFinList, FODelegate, FixedFinDataDelegate)
- fixedExpenditureVC → mainVC 전달: NotificationCenter (`toMainVC`)
- 모든 데이터 변경은 didSet에서 UserDefaults에 자동 저장

## Refactoring Status

### Phase 1: Force Unwrap / Crash 방지 - DONE (b75081c)
- 전체 8개 파일, 50곳+ 강제 언래핑 제거
- 모델에 커스텀 Codable 디코더 추가 (기존 데이터 호환)

### Phase 2: 데이터 레이어 안전화 - TODO
- UserDefaults 인코딩/디코딩 패턴 통일
- didSet 내 인코딩 실패 시 로깅 추가
- loadAndFixFinData 패턴을 fixedFinList, profile, salarydata에도 확대 적용

### Phase 3: 코드 품질 개선 - TODO
- 네이밍 컨벤션: `finData` → `FinData`, `salaryDate` → `SalaryDate`, `profile` → `Profile`, `sourceView` → `SourceView`, `mode` → `Mode`
  - 주의: Codable CodingKeys는 유지해야 UserDefaults 데이터 호환 가능 (커스텀 CodingKeys 필요)
- 중복 제거: `numberFormatter(number:)` 3곳 → `Int.toDecimal()` 통합
- 중복 제거: `addInputAccessoryForTextFields` (addFinVC, fixedExpenditureVC)
- 중복 제거: `tableCellBorderLayout` (searchCell, fixedExpenditureCell, calendarVC)
- 중복 제거: DatePicker 관련 코드 (mainVC, revenueVC 거의 동일)
- 주석/미사용 코드 정리

### Phase 4: 구조 개선 (선택) - TODO
- mainVC (695줄) 경량화: DataSource/Delegate 분리, 비즈니스 로직 추출
- UserDefaults 접근을 DataStore/Repository 패턴으로 통합

## Conventions
- 커밋 메시지: 한국어 본문 허용, prefix는 영어 (refactor:, fix:, feat:)
- 빌드 대상: iPhone 16 Simulator (OS 18.5)
