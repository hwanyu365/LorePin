# LorePin Changelog

## [1.1.0] - 2026-11-15

### Added
- 사용자 카테고리: 설정 패널에서 이름·아이콘(12개 중 선택)·색을 정해 만들고 지운다. 지우면 그 카테고리의 핀도 함께 지워진다 (확인 대화상자에 핀 수).
- 핀 목록에서 여러 핀을 골라 카테고리를 한꺼번에 바꾸거나 지운다 (확인 대화상자).
- 핀 목록의 카테고리 필터가 여러 개를 고르는 드롭다운으로 바뀌었다 → 카테고리가 많아도 폭이 그대로다.
- ESC 로 LorePin 창(생성 팝업·상세 패널·목록)을 닫는다. 상세 패널에 저장하지 않은 변경이 있으면 버릴지 묻는다.
- 설정 패널 제목에 애드온 버전을 표시한다.

### Changed
- 입력 오류는 [저장] 버튼을 막고 마우스를 올리면 이유를 보여 준다. 잘못된 좌표 칸은 빨간색이다.
- 저장·실행 실패는 화면 상단 오류 문구로도 보인다 (채팅창에도 남음).
- 핀 목록에서 행을 우클릭해도 상세 패널이 열린다.

### Removed
- `/lp detail <id>`·`/lp delete <id>` 명령 → 조회·삭제는 목록과 상세 패널에서 한다.
- 설정 패널의 미니맵 항목 → 미니맵 핀 표시는 제공하지 않는다.

### Fixed
- 공백만 있는 제목으로 핀이 저장되던 문제.

## [1.0.2] - 2026-10-18

### Changed
- Interface 번호를 `120105` (Midnight 12.1.5) 로 갱신.

## [1.0.1] - 2026-08-15

### Changed
- Interface 번호를 `120100` (Midnight 12.1) 으로 갱신.

## [1.0.0] - 2026-04-18

Initial public release.

### Features
- **Personal pin system**: drop pins at any world map location with a title, note, and category.
  Everything persists across sessions and is shared across all characters on the account.
- **Six built-in categories** (General, Quest, Danger, Gather, Scenic, Complete) plus
  user-defined custom categories.
- **World map rendering**: pins appear as colored, category-iconned markers on the
  world map. Hovering shows a tooltip with title, category, note, and coordinates.
- **Unified detail / edit panel**: left-click a pin on the map or a row in the list
  to open it. Fields are always editable; the button row switches between
  `[Waypoint] [TomTom] [Delete] [Close]` and `[Save] [Cancel] [Close]` based on
  whether there are unsaved changes. An asterisk (`*`) marks unsaved state.
- **Pin creation popup** with editable X/Y coordinates, `[Current Location]`,
  and `[Pick on Map]` mode. ESC or right-click on the map cancels picking and
  restores the popup with its previous content.
- **List panel** (`/lp list`) with search, multi-select category filter,
  and sort by newest / oldest / map. Per-row `[Waypoint]` and `[TomTom]`
  toggle buttons for quick navigation.
- **Blizzard Settings panel** (`/lp settings`) for world-map / minimap visibility,
  icon size, maximum pin count, reset-settings, reset-all-pins, and
  open-pin-list shortcuts.
- **Waypoint integration**: built-in WoW user waypoint (toggle, only one pin
  can be active at a time) plus optional TomTom integration when that addon
  is installed (toggle per pin, automatic cleanup on pin deletion).
- **Korean and English** localization.

### Commands
- `/lp` — open the new-pin popup at the player's current location
- `/lp <title>` — quick-create a pin with a pre-filled title
- `/lp list` — open the pin list panel
- `/lp detail <id>` — open the detail panel for a specific pin
- `/lp delete <id>` — delete a pin by ID
- `/lp settings` — open the settings panel
- `/lp help` — show help in chat

### Technical notes
- Built on pure WoW API (Lua 5.1), no external library dependencies.
- UI built through a shared `UI/Layout.lua` helper module (constants,
  dialog scaffolding, form rows, button rows, state helpers) that enforces
  consistent alignment, chrome offsets, label centering, and button states
  across all dialogs.
- Account-wide `SavedVariables` (`LorePinDB`).
- Midnight (12.0.0+) compatible; Interface 120000.
