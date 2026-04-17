local _, ns = ...

local panel = nil
local MARGIN     = 16
local ROW_HEIGHT = 30
local HEADER_H   = 120  -- total height of search/filter/sort header (+16 for title breathing room)
local ROW_BTN_W  = 70   -- width of per-row action buttons

-- UI state
-- activeCategories: set-style table { [catId] = true }. Empty table = show all.
local state = {
    searchText       = "",
    activeCategories = {},
    sortMode         = "newest",  -- newest | oldest | map
}

local function HasAnyFilter()
    for _ in pairs(state.activeCategories) do return true end
    return false
end

local function IsCategoryActive(catId)
    return state.activeCategories[catId] == true
end

local function ToggleCategory(catId)
    if state.activeCategories[catId] then
        state.activeCategories[catId] = nil
    else
        state.activeCategories[catId] = true
    end
end

local function ClearCategoryFilter()
    wipe(state.activeCategories)
end

-- ─── Sorting / filtering ─────────────────────────────────────────────────────

local function FilterPins(pins)
    local result = {}
    local q = state.searchText ~= "" and state.searchText:lower() or nil

    for _, pin in ipairs(pins) do
        local ok = true
        if HasAnyFilter() and not IsCategoryActive(pin.category) then
            ok = false
        end
        if ok and q then
            local title = (pin.title or ""):lower()
            local note  = (pin.note  or ""):lower()
            if not (title:find(q, 1, true) or note:find(q, 1, true)) then
                ok = false
            end
        end
        if ok then result[#result + 1] = pin end
    end
    return result
end

local function SortPins(pins)
    if state.sortMode == "newest" then
        table.sort(pins, function(a, b) return (a.createdAt or 0) > (b.createdAt or 0) end)
    elseif state.sortMode == "oldest" then
        table.sort(pins, function(a, b) return (a.createdAt or 0) < (b.createdAt or 0) end)
    elseif state.sortMode == "map" then
        table.sort(pins, function(a, b)
            if (a.mapID or 0) ~= (b.mapID or 0) then return (a.mapID or 0) < (b.mapID or 0) end
            return (a.createdAt or 0) > (b.createdAt or 0)
        end)
    end
    return pins
end

-- ─── Row factory ─────────────────────────────────────────────────────────────

local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", 4, 0)
    icon:SetSize(22, 22)
    row.icon = icon

    local title = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 5)
    title:SetJustifyH("LEFT")
    row.titleText = title

    local meta = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    meta:SetPoint("LEFT", icon, "RIGHT", 8, -9)
    meta:SetJustifyH("LEFT")
    row.metaText = meta

    -- Row action buttons: TomTom | Waypoint (right-aligned)
    local btnTomTom = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    btnTomTom:SetSize(ROW_BTN_W, ROW_HEIGHT - 8)
    btnTomTom:SetPoint("RIGHT", -4, 0)
    btnTomTom:SetText(ns.L.LIST_ROW_TOMTOM)
    row.btnTomTom = btnTomTom

    local btnWaypoint = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    btnWaypoint:SetSize(ROW_BTN_W, ROW_HEIGHT - 8)
    btnWaypoint:SetPoint("RIGHT", btnTomTom, "LEFT", -4, 0)
    btnWaypoint:SetText(ns.L.LIST_ROW_WAYPOINT)
    row.btnWaypoint = btnWaypoint

    btnWaypoint:RegisterForClicks("LeftButtonUp")
    btnTomTom:RegisterForClicks("LeftButtonUp")

    -- Waypoint button is also a toggle; only one pin can own the user
    -- waypoint at a time, so after toggling we refresh every row's button.
    local function RefreshWaypointButton()
        local pin = row.pinData
        if not pin then return end
        if ns:HasActiveWaypoint(pin) then
            btnWaypoint:LockHighlight()
        else
            btnWaypoint:UnlockHighlight()
        end
    end
    row.RefreshWaypointButton = RefreshWaypointButton

    btnWaypoint:SetScript("OnClick", function()
        local pin = row.pinData
        if not pin then return end
        ns:ToggleWaypointForPin(pin)
        -- Only one pin can be active; refresh all rows, not just this one
        if ns.RefreshWaypointButtons then ns:RefreshWaypointButtons() end
    end)

    -- TomTom button is a toggle: click to add, click again to remove.
    local function RefreshTomTomButton()
        local pin = row.pinData
        if not pin then return end
        if not ns:IsTomTomLoaded() then
            ns.Layout.SetButtonDisabled(btnTomTom, true)
            btnTomTom:UnlockHighlight()
            return
        end
        ns.Layout.SetButtonDisabled(btnTomTom, false)
        if ns:HasTomTomWaypoint(pin.id) then
            btnTomTom:LockHighlight()
        else
            btnTomTom:UnlockHighlight()
        end
    end
    row.RefreshTomTomButton = RefreshTomTomButton

    btnTomTom:SetScript("OnClick", function()
        local pin = row.pinData
        if not pin then return end
        local result, err = ns:ToggleTomTomForPin(pin)
        if not result then
            if err then ns:Print(err) end
            return
        end
        RefreshTomTomButton()
    end)

    return row
end

local function FormatRow(row, pin)
    row.pinData = pin

    local cat = ns:GetCategoryById(pin.category)
    if cat then
        row.icon:SetTexture(cat.icon)
        row.icon:SetVertexColor(cat.color.r, cat.color.g, cat.color.b, 1.0)
    else
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon:SetVertexColor(1, 1, 1, 1)
    end

    row.titleText:SetText(string.format("[%d] %s", pin.id, pin.title or ""))

    local mapInfo = C_Map.GetMapInfo(pin.mapID or 0)
    local mapName = (mapInfo and mapInfo.name) or ("Map " .. tostring(pin.mapID))
    local dateStr = date("%Y-%m-%d", pin.createdAt or 0)
    row.metaText:SetText(string.format("%s  |  %s", mapName, dateStr))

    if row.RefreshTomTomButton   then row.RefreshTomTomButton()   end
    if row.RefreshWaypointButton then row.RefreshWaypointButton() end
end

-- Called after a waypoint toggle — updates every row so at most one shows
-- the "active" highlight (since WoW keeps only one user waypoint at a time).
function ns:RefreshWaypointButtons()
    if not panel then return end
    for _, row in ipairs(panel.rows or {}) do
        if row.RefreshWaypointButton then row.RefreshWaypointButton() end
    end
end

-- ─── Panel construction ──────────────────────────────────────────────────────

local function EnsurePanel()
    if panel then return panel end
    local L = ns.L
    local Layout = ns.Layout

    local f = CreateFrame("Frame", "LorePinListPanel", UIParent, "BackdropTemplate")
    f:SetSize(540, 556)
    f:SetPoint("CENTER")
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        edgeSize = 26,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -14)
    f.title:SetText(L.LIST_TITLE)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -10, -10)

    -- Search box (label + field anchored to each other so the gap stays
    -- constant regardless of translated label length).
    -- Content starts at y=-60, giving ~16px clearance from the title (y=-14)
    -- to match the spacing between the bottom button row and the content above it.
    local searchLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", MARGIN, -60)
    searchLabel:SetText(L.LIST_SEARCH)

    local searchEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    searchEdit:SetPoint("LEFT", searchLabel, "RIGHT", 12, 0)
    searchEdit:SetSize(240, 22)
    searchEdit:SetAutoFocus(false)
    searchEdit:SetMaxLetters(80)
    searchEdit:SetScript("OnTextChanged", function(self)
        state.searchText = self:GetText() or ""
        ns:RefreshPinList()
    end)
    searchEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.searchEdit = searchEdit

    -- Sort dropdown. Uses Layout.DROPDOWN_RIGHT_OFFSET to compensate for the
    -- invisible right-side chrome so the visible right edge aligns with MARGIN.
    local sortDropdown = CreateFrame("Frame", "LorePinListSortDropdown", f, "UIDropDownMenuTemplate")
    sortDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", -MARGIN + Layout.DROPDOWN_RIGHT_OFFSET, -52)
    UIDropDownMenu_SetWidth(sortDropdown, 110)
    f.sortDropdown = sortDropdown

    local function UpdateSortText()
        local labels = {
            newest = L.LIST_SORT_NEWEST,
            oldest = L.LIST_SORT_OLDEST,
            map    = L.LIST_SORT_MAP,
        }
        UIDropDownMenu_SetText(sortDropdown, labels[state.sortMode] or state.sortMode)
    end

    UIDropDownMenu_Initialize(sortDropdown, function(_, level)
        local modes = {
            { id = "newest", label = L.LIST_SORT_NEWEST },
            { id = "oldest", label = L.LIST_SORT_OLDEST },
            { id = "map",    label = L.LIST_SORT_MAP },
        }
        for _, m in ipairs(modes) do
            local info = UIDropDownMenu_CreateInfo()
            info.text    = m.label
            info.value   = m.id
            info.checked = (state.sortMode == m.id)
            info.func    = function(btn)
                state.sortMode = btn.value
                UpdateSortText()
                CloseDropDownMenus()
                ns:RefreshPinList()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    f.UpdateSortText = UpdateSortText

    -- Category filter buttons (single row)
    local filterContainer = CreateFrame("Frame", nil, f)
    filterContainer:SetPoint("TOPLEFT", MARGIN, -88)
    filterContainer:SetPoint("RIGHT", f, "RIGHT", -MARGIN, 0)
    filterContainer:SetHeight(24)
    f.filterContainer = filterContainer

    -- Button state helpers use Layout.SetButtonActive for safe highlight +
    -- alpha toggling (UIPanelButtonTemplate has no reliable NormalTexture).
    local function ApplyButtonState(btn, cat, active)
        local dim = { r = cat.color.r * 0.7, g = cat.color.g * 0.7, b = cat.color.b * 0.7 }
        Layout.SetButtonActive(btn, active, cat.color, dim)
    end

    local function ApplyAllButtonState(btn, allActive)
        Layout.SetButtonActive(btn, allActive,
            { r = 1, g = 1, b = 1 },
            { r = 0.7, g = 0.7, b = 0.7 })
    end

    local function RebuildCategoryFilters()
        if f.filterButtons then
            for _, b in ipairs(f.filterButtons) do b:Hide(); b:SetParent(nil) end
        end
        f.filterButtons = {}
        f.catFilterButtons = {}

        -- "All" button — clears filter
        local allBtn = CreateFrame("Button", nil, filterContainer, "UIPanelButtonTemplate")
        allBtn:SetHeight(22)
        allBtn:SetText(L.LIST_FILTER_ALL)
        allBtn:SetScript("OnClick", function()
            ClearCategoryFilter()
            ns:RefreshPinList()
        end)
        f.allFilterButton = allBtn
        table.insert(f.filterButtons, allBtn)

        for _, cat in ipairs(ns:GetCategories()) do
            local btn = CreateFrame("Button", nil, filterContainer, "UIPanelButtonTemplate")
            btn:SetHeight(22)
            btn:SetText(cat.name)
            btn._cat = cat
            btn:SetScript("OnClick", function(self)
                ToggleCategory(self._cat.id)
                ns:RefreshPinList()
            end)
            table.insert(f.filterButtons, btn)
            f.catFilterButtons[cat.id] = btn
        end

        -- Layout helper distributes all buttons across the container width
        Layout.EquallyDistributeButtons(filterContainer, f.filterButtons, 4)

        -- Apply initial visual state
        ApplyAllButtonState(allBtn, not HasAnyFilter())
        for catId, btn in pairs(f.catFilterButtons) do
            ApplyButtonState(btn, btn._cat, IsCategoryActive(catId))
        end
    end
    f.RebuildCategoryFilters = RebuildCategoryFilters

    f.RefreshFilterStates = function()
        if f.allFilterButton then
            ApplyAllButtonState(f.allFilterButton, not HasAnyFilter())
        end
        if f.catFilterButtons then
            for catId, btn in pairs(f.catFilterButtons) do
                ApplyButtonState(btn, btn._cat, IsCategoryActive(catId))
            end
        end
    end

    -- Scrollable list area with a dark inset background, similar to the
    -- note box in PinPopup/DetailPanel. The background makes the list
    -- visually distinct from the rest of the panel.
    local listBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    listBg:SetPoint("TOPLEFT", MARGIN, -HEADER_H)
    listBg:SetPoint("BOTTOMRIGHT", -MARGIN, 56)
    listBg:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    listBg:SetBackdropColor(0, 0, 0, 0.5)
    listBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    f.listBg = listBg

    -- Scroll frame sits inside the backdrop, insetting to leave room for the
    -- border and the scrollbar chrome on the right.
    local scroll = CreateFrame("ScrollFrame", nil, listBg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)

    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(1, 1)
    scroll:SetScrollChild(scrollChild)
    f.scrollFrame = scroll
    f.scrollChild = scrollChild
    f.rows = {}

    -- Bottom row: total count (left) + New Pin button (right)
    local totalText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    totalText:SetPoint("BOTTOMLEFT", MARGIN, 22)
    f.totalText = totalText

    local newBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    newBtn:SetSize(100, 24)
    newBtn:SetPoint("BOTTOMRIGHT", -MARGIN, 16)
    newBtn:SetText(L.LIST_NEW_PIN)
    newBtn:SetScript("OnClick", function()
        ns:ShowPinPopup()
    end)
    f.newPinButton = newBtn

    panel = f
    return f
end

-- ─── Refresh ─────────────────────────────────────────────────────────────────

function ns:RefreshPinList()
    local f = EnsurePanel()
    if not f:IsShown() then return end

    local L = self.L
    if f.RefreshFilterStates then f.RefreshFilterStates() end
    local pins = FilterPins(self:GetAllPins())
    SortPins(pins)

    -- Ensure row pool size
    local rows = f.rows
    local scrollChild = f.scrollChild
    local width = f.scrollFrame:GetWidth()

    for i = 1, #pins do
        local row = rows[i]
        if not row then
            row = CreateRow(scrollChild)
            rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetWidth(width)
        FormatRow(row, pins[i])

        row:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                self:GetParent():GetParent().lastEditedPinId = self.pinData.id
                ns:ShowPinPopup({
                    editPinId = self.pinData.id,
                    onSaved   = function() ns:RefreshPinList() end,
                })
            else
                ns:ShowPinDetail(self.pinData.id)
            end
        end)
        row:Show()
    end

    -- Hide unused rows
    for i = #pins + 1, #rows do
        rows[i]:Hide()
    end

    scrollChild:SetSize(math.max(1, width), math.max(1, #pins * ROW_HEIGHT))

    f.totalText:SetText(string.format(L.LIST_TOTAL_COUNT, #pins))

    if #pins == 0 then
        if not f.emptyText then
            local em = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            em:SetPoint("CENTER", f.scrollFrame, "CENTER", 0, 0)
            f.emptyText = em
        end
        f.emptyText:SetText(L.LIST_EMPTY)
        f.emptyText:Show()
    elseif f.emptyText then
        f.emptyText:Hide()
    end
end

function ns:ShowPinList()
    local f = EnsurePanel()
    f.searchEdit:SetText(state.searchText or "")
    f.UpdateSortText()
    -- Show BEFORE building filters so filterContainer:GetWidth() returns the
    -- correct layout-resolved width for even button distribution.
    f:Show()
    f.RebuildCategoryFilters()
    self:RefreshPinList()
end
