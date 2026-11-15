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
    selected         = {},        -- { [pinId] = true }, only pins visible in the list
}

local function SelectedIds()
    local ids = {}
    for id in pairs(state.selected) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

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

-- ─── Row factory ─────────────────────────────────────────────────────────────

local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)

    -- A child button takes the click, so ticking it does not open the detail panel.
    local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("LEFT", 0, 0)
    check:SetScript("OnClick", function(self)
        local pin = row.pinData
        if not pin then return end
        state.selected[pin.id] = self:GetChecked() and true or nil
        if ns.RefreshSelectionBar then ns:RefreshSelectionBar() end
    end)
    row.check = check

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", check, "RIGHT", 2, 0)
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
            if err then ns:NotifyError(err) end
            return
        end
        RefreshTomTomButton()
    end)

    return row
end

local function FormatRow(row, pin)
    row.pinData = pin
    row.check:SetChecked(state.selected[pin.id] == true)

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
    Layout.CloseOnEscape(f, nil, { "LOREPIN_LIST_CHANGE_CATEGORY", "LOREPIN_LIST_DELETE_SELECTED" })
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

    -- Category filter: multi-select dropdown, so the header width stays fixed however many categories exist.
    local filterLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    filterLabel:SetPoint("TOPLEFT", MARGIN, -94)
    filterLabel:SetText(L.LIST_FILTER_LABEL)

    local filterDropdown = CreateFrame("Frame", "LorePinListFilterDropdown", f, "UIDropDownMenuTemplate")
    filterDropdown:SetPoint("LEFT", filterLabel, "RIGHT", -4, -2)
    UIDropDownMenu_SetWidth(filterDropdown, 200)
    f.filterDropdown = filterDropdown

    local function RefreshFilterText()
        UIDropDownMenu_SetText(filterDropdown, ns:DescribeCategoryFilter(state.activeCategories))
    end

    -- Row layout is [icon] [name] ... [check]. UIDropDownMenu only draws its check on the left,
    -- so rows are not checkable and the right-side icon slot draws the check box instead.
    local CHECK_TEXTURE = [[Interface\Common\UI-DropDownRadioChecks]]
    local ALL_VALUE = "__all"

    local function IsRowChecked(value)
        if value == ALL_VALUE then return not HasAnyFilter() end
        return IsCategoryActive(value)
    end

    local function ApplyCheck(icon, checked)
        if checked then icon:SetTexCoord(0, 0.5, 0, 0.5) else icon:SetTexCoord(0.5, 1, 0, 0.5) end
    end

    -- Every row changes when [All] is pressed, so all visible rows are redrawn after any click.
    local function RefreshOpenChecks()
        local list = _G["DropDownList1"]
        if not list or list.dropdown ~= filterDropdown then return end
        for i = 1, list.numButtons or 0 do
            local row = _G["DropDownList1Button" .. i]
            local icon = row and (row.Icon or _G[row:GetName() .. "Icon"])
            if icon and row.value ~= nil then ApplyCheck(icon, IsRowChecked(row.value)) end
        end
    end

    local function AddRow(level, text, value, onClick)
        local info = UIDropDownMenu_CreateInfo()
        info.text = text
        info.value = value
        info.notCheckable = true
        info.keepShownOnClick = true
        info.icon = CHECK_TEXTURE
        local checked = IsRowChecked(value)
        info.tCoordLeft, info.tCoordRight = checked and 0 or 0.5, checked and 0.5 or 1
        info.tCoordTop, info.tCoordBottom = 0, 0.5
        info.func = function(btn)
            onClick(btn.value)
            RefreshFilterText()
            ns:RefreshPinList()
            RefreshOpenChecks()
        end
        UIDropDownMenu_AddButton(info, level)
    end

    UIDropDownMenu_Initialize(filterDropdown, function(_, level)
        AddRow(level, L.LIST_FILTER_ALL, ALL_VALUE, function() ClearCategoryFilter() end)
        for _, cat in ipairs(ns:GetCategories()) do
            local color = string.format("|cff%02x%02x%02x", cat.color.r * 255, cat.color.g * 255, cat.color.b * 255)
            local text = string.format("|T%s:16:16|t %s%s|r", cat.icon, color, cat.name)
            AddRow(level, text, cat.id, ToggleCategory)
        end
    end)

    f.RebuildCategoryFilters = RefreshFilterText
    f.RefreshFilterStates = RefreshFilterText

    -- Scrollable list area with a dark inset background, similar to the
    -- note box in PinPopup/DetailPanel. The background makes the list
    -- visually distinct from the rest of the panel.
    local listBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    listBg:SetPoint("TOPLEFT", MARGIN, -HEADER_H)
    listBg:SetPoint("BOTTOMRIGHT", -MARGIN, 88)
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

    -- Selection row: count, [Select All], [Clear], [Change Category], [Delete]
    local selText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    selText:SetPoint("BOTTOMLEFT", MARGIN, 64)

    local function SelBtn(text, w)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        b:SetText(text)
        return b
    end

    local selectAllBtn = SelBtn(L.LIST_SELECT_ALL, 84)
    selectAllBtn:SetPoint("BOTTOMLEFT", MARGIN + 64, 58)
    local clearBtn = SelBtn(L.LIST_SELECT_NONE, 84)
    clearBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 4, 0)

    local changeDropdown = CreateFrame("Frame", "LorePinListChangeCategoryDropdown", f, "UIDropDownMenuTemplate")
    changeDropdown:SetPoint("LEFT", clearBtn, "RIGHT", -12, -2)
    UIDropDownMenu_SetWidth(changeDropdown, 110)
    UIDropDownMenu_SetText(changeDropdown, L.LIST_CHANGE_CATEGORY)

    local deleteBtn = SelBtn(L.LIST_DELETE_SELECTED, 84)
    deleteBtn:SetPoint("BOTTOMRIGHT", -MARGIN, 58)

    selectAllBtn:SetScript("OnClick", function()
        for _, row in ipairs(f.rows) do
            if row:IsShown() and row.pinData then state.selected[row.pinData.id] = true end
        end
        ns:RefreshPinList()
    end)
    clearBtn:SetScript("OnClick", function()
        wipe(state.selected)
        ns:RefreshPinList()
    end)

    local function ClearSelectionAndRefresh()
        wipe(state.selected)
        ns:RefreshPinList()
    end

    StaticPopupDialogs["LOREPIN_LIST_CHANGE_CATEGORY"] = {
        text = "",
        button1 = YES, button2 = NO,
        OnAccept = function(_, data)
            local changed = ns:SetPinsCategory(data.ids, data.categoryId)
            if changed then ns:Print(string.format(L.LIST_CHANGED, changed, data.name)) end
            ClearSelectionAndRefresh()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["LOREPIN_LIST_DELETE_SELECTED"] = {
        text = "",
        button1 = YES, button2 = NO,
        OnAccept = function(_, data)
            local removed = ns:DeletePins(data.ids)
            ns:Print(string.format(L.LIST_DELETED, removed))
            ClearSelectionAndRefresh()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    UIDropDownMenu_Initialize(changeDropdown, function(_, level)
        for _, cat in ipairs(ns:GetCategories()) do
            local info = UIDropDownMenu_CreateInfo()
            local color = string.format("|cff%02x%02x%02x", cat.color.r * 255, cat.color.g * 255, cat.color.b * 255)
            info.text = string.format("|T%s:16:16|t %s%s|r", cat.icon, color, cat.name)
            info.notCheckable = true
            info.func = function()
                CloseDropDownMenus()
                local ids = SelectedIds()
                if #ids == 0 then return end
                StaticPopupDialogs["LOREPIN_LIST_CHANGE_CATEGORY"].text = string.format(L.LIST_CHANGE_CONFIRM, #ids, cat.name)
                StaticPopup_Show("LOREPIN_LIST_CHANGE_CATEGORY", nil, nil, { ids = ids, categoryId = cat.id, name = cat.name })
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    deleteBtn:SetScript("OnClick", function()
        local ids = SelectedIds()
        if #ids == 0 then return end
        StaticPopupDialogs["LOREPIN_LIST_DELETE_SELECTED"].text = string.format(L.LIST_DELETE_CONFIRM, #ids)
        StaticPopup_Show("LOREPIN_LIST_DELETE_SELECTED", nil, nil, { ids = ids })
    end)

    f.RefreshSelectionBar = function()
        local count = #SelectedIds()
        selText:SetText(string.format(L.LIST_SELECTED, count))
        local any = count > 0
        clearBtn:SetEnabled(any)
        deleteBtn:SetEnabled(any)
        if any then UIDropDownMenu_EnableDropDown(changeDropdown) else UIDropDownMenu_DisableDropDown(changeDropdown) end
    end

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
    self:DropUnknownCategories(state.activeCategories)

    local L = self.L
    if f.RefreshFilterStates then f.RefreshFilterStates() end
    local pins = self:SortPins(self:FilterPins(self:GetAllPins(), state.searchText, state.activeCategories), state.sortMode)
    self:KeepVisibleSelection(state.selected, pins)
    f.RefreshSelectionBar()

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

        row:SetScript("OnClick", function(self)
            ns:ShowPinDetail(self.pinData.id)
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
    f:Show()
    f.RebuildCategoryFilters()
    self:RefreshPinList()
end

function ns:RefreshCategoryFilters()
    if not panel or not panel:IsShown() then return end
    self:DropUnknownCategories(state.activeCategories)
    panel.RebuildCategoryFilters()
    self:RefreshPinList()
end

function ns:ForgetCategoryFilter(id)
    state.activeCategories[id] = nil
end

function ns:RefreshSelectionBar()
    if panel then panel.RefreshSelectionBar() end
end
