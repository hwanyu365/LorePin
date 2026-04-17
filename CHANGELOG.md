# LorePin Changelog

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
