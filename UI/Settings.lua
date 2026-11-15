local _, ns = ...

---------------------------------------------------------------------------
-- Layout constants
---------------------------------------------------------------------------
local MARGIN           = 16
local TITLE_Y          = -16
local CONTENT_Y        = -50
local CHECKBOX_SPACING = 30
local SLIDER_HEIGHT    = 17
local SLIDER_WIDTH     = 220

local FONT_TITLE  = "GameFontNormalLarge"
local FONT_HEADER = "GameFontNormal"

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function CreateCheckbox(parent, x, y, text, getter, setter, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(text)
    cb.Text:ClearAllPoints()
    cb.Text:SetPoint("LEFT", cb, "RIGHT", 3, 0)
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked())
        if onChange then onChange() end
    end)
    cb._getter = getter
    return cb
end

local function CreateSlider(parent, x, y, label, minVal, maxVal, step, getter, setter, onChange)
    local lab = parent:CreateFontString(nil, "ARTWORK", FONT_HEADER)
    lab:SetPoint("TOPLEFT", x, y)
    lab:SetText(label)

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x + 4, y - 18)
    slider:SetSize(SLIDER_WIDTH, SLIDER_HEIGHT)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    slider.Low:SetText(tostring(minVal))
    slider.High:SetText(tostring(maxVal))

    local valueText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)

    slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val / step + 0.5) * step
        valueText:SetText(tostring(val))
        setter(val)
        if onChange then onChange() end
    end)

    slider._getter = getter
    slider._refreshValue = function()
        local v = getter()
        slider:SetValue(v)
        valueText:SetText(tostring(v))
    end

    return slider
end

---------------------------------------------------------------------------
-- Custom categories section
---------------------------------------------------------------------------
local ICON_BTN   = 24
local ICON_GAP   = 4
local ROW_H      = 26
local LIST_ROWS  = 6
local WHITE      = { r = 1.0, g = 1.0, b = 1.0 }

local function CopyColor(c) return { r = c.r, g = c.g, b = c.b } end

local function BuildCategorySection(panel, y)
    local L = ns.L
    local Layout = ns.Layout

    local header = panel:CreateFontString(nil, "ARTWORK", FONT_HEADER)
    header:SetPoint("TOPLEFT", MARGIN, y)
    header:SetText(L.CATEGORY_SECTION)
    y = y - 26

    -- Add row: name, color swatch, [Add]
    local nameLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    nameLabel:SetPoint("TOPLEFT", MARGIN, y - 4)
    nameLabel:SetText(L.CATEGORY_NAME)

    local nameEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    nameEdit:SetPoint("TOPLEFT", MARGIN + 60, y)
    nameEdit:SetSize(180, 22)
    nameEdit:SetAutoFocus(false)
    nameEdit:SetMaxLetters(64)
    nameEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local colorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    colorLabel:SetPoint("LEFT", nameEdit, "RIGHT", 14, 0)
    colorLabel:SetText(L.CATEGORY_COLOR)

    local swatch = CreateFrame("Button", nil, panel, "BackdropTemplate")
    swatch:SetPoint("LEFT", colorLabel, "RIGHT", 8, 0)
    swatch:SetSize(22, 22)
    swatch:SetBackdrop({ edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10 })
    swatch.fill = swatch:CreateTexture(nil, "ARTWORK")
    swatch.fill:SetPoint("TOPLEFT", 3, -3)
    swatch.fill:SetPoint("BOTTOMRIGHT", -3, 3)

    local addBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addBtn:SetPoint("LEFT", swatch, "RIGHT", 14, 0)
    addBtn:SetSize(90, 24)
    addBtn:SetText(L.CATEGORY_ADD)
    y = y - 32

    -- Icon choices
    local iconLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    iconLabel:SetPoint("TOPLEFT", MARGIN, y - 6)
    iconLabel:SetText(L.CATEGORY_ICON)

    local state = { icon = ns.CUSTOM_CATEGORY_ICONS[1], color = CopyColor(WHITE) }
    local iconButtons = {}

    local function RefreshIcons()
        for _, b in ipairs(iconButtons) do b.selected:SetShown(b.path == state.icon) end
    end
    local function SetColor(c)
        state.color = CopyColor(c)
        swatch.fill:SetColorTexture(c.r, c.g, c.b)
    end

    for i, path in ipairs(ns.CUSTOM_CATEGORY_ICONS) do
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(ICON_BTN, ICON_BTN)
        b:SetPoint("TOPLEFT", MARGIN + 60 + (i - 1) * (ICON_BTN + ICON_GAP), y)
        b.path = path
        local tex = b:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(path)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b.selected = b:CreateTexture(nil, "OVERLAY")
        b.selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        b.selected:SetBlendMode("ADD")
        b.selected:SetAllPoints()
        b:SetScript("OnClick", function(self)
            state.icon = self.path
            RefreshIcons()
        end)
        iconButtons[i] = b
    end
    y = y - (ICON_BTN + 14)

    swatch:SetScript("OnClick", function()
        local before = CopyColor(state.color)
        ColorPickerFrame:SetupColorPickerAndShow({
            r = before.r, g = before.g, b = before.b,
            hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                SetColor({ r = r, g = g, b = b })
            end,
            cancelFunc = function() SetColor(before) end,
        })
    end)

    local function RefreshAddState()
        local ok, reason = ns:CheckCategoryName(nameEdit:GetText())
        Layout.SetBlockedReasons(addBtn, ok and {} or { reason })
    end
    nameEdit:SetScript("OnTextChanged", RefreshAddState)

    -- Existing custom categories
    local emptyText = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    emptyText:SetPoint("TOPLEFT", MARGIN, y)
    emptyText:SetText(L.CATEGORY_NONE)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", MARGIN, y)
    scroll:SetSize(420, ROW_H * LIST_ROWS)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(400, 1)
    scroll:SetScrollChild(content)

    local rows = {}
    local function GetRow(i)
        if rows[i] then return rows[i] end
        local r = CreateFrame("Frame", nil, content)
        r:SetSize(400, ROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(20, 20)
        r.icon:SetPoint("LEFT", 2, 0)
        r.color = r:CreateTexture(nil, "ARTWORK")
        r.color:SetSize(12, 12)
        r.color:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.name = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        r.name:SetPoint("LEFT", r.color, "RIGHT", 8, 0)
        r.delete = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.delete:SetSize(70, 22)
        r.delete:SetPoint("RIGHT", -4, 0)
        r.delete:SetText(L.BUTTON_DELETE)
        rows[i] = r
        return r
    end

    local function RefreshList()
        local list = ns.db.customCategories or {}
        for i, cat in ipairs(list) do
            local r = GetRow(i)
            r.icon:SetTexture(cat.icon)
            local c = cat.color or WHITE
            r.color:SetColorTexture(c.r, c.g, c.b)
            r.name:SetText(cat.name)
            r.delete:SetScript("OnClick", function()
                local count = 0
                for _, pin in ipairs(ns:GetAllPins()) do
                    if pin.category == cat.id then count = count + 1 end
                end
                local dialog = StaticPopupDialogs["LOREPIN_DELETE_CATEGORY_CONFIRM"]
                dialog.text = count > 0
                    and string.format(L.CATEGORY_DELETE_CONFIRM_PINS, cat.name, count)
                    or string.format(L.CATEGORY_DELETE_CONFIRM, cat.name)
                StaticPopup_Show("LOREPIN_DELETE_CATEGORY_CONFIRM", nil, nil, { id = cat.id, name = cat.name })
            end)
            r:Show()
        end
        for i = #list + 1, #rows do rows[i]:Hide() end
        content:SetHeight(math.max(1, #list * ROW_H))
        emptyText:SetShown(#list == 0)
        scroll:SetShown(#list > 0)
    end
    ns.RefreshCategorySection = RefreshList

    local function ResetInputs()
        nameEdit:SetText("")
        nameEdit:ClearFocus()
        state.icon = ns.CUSTOM_CATEGORY_ICONS[1]
        RefreshIcons()
        SetColor(WHITE)
        RefreshAddState()
    end

    local function Add()
        local cat, reason = ns:CreateCustomCategory(nameEdit:GetText(), state.icon, state.color)
        if not cat then
            ns:NotifyError(reason)
            return
        end
        ns:Print(string.format(L.CATEGORY_ADDED, cat.name))
        ResetInputs()
        RefreshList()
        if ns.RefreshCategoryFilters then ns:RefreshCategoryFilters() end
    end
    addBtn:SetScript("OnClick", Add)
    nameEdit:SetScript("OnEnterPressed", function() if addBtn:IsEnabled() then Add() end end)

    StaticPopupDialogs["LOREPIN_DELETE_CATEGORY_CONFIRM"] = {
        text = "",
        button1 = YES, button2 = NO,
        OnAccept = function(_, data)
            local count = ns:DeleteCustomCategory(data.id)
            if count then ns:Print(string.format(L.CATEGORY_DELETED, data.name, count)) end
            RefreshList()
            if ns.RefreshCategoryFilters then ns:RefreshCategoryFilters() end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    ResetInputs()
    RefreshList()
end

---------------------------------------------------------------------------
-- Settings initializer
---------------------------------------------------------------------------
function ns:InitSettings()
    local L = self.L
    local db = self.db

    -- Static popups
    StaticPopupDialogs["LOREPIN_RESET_PINS_CONFIRM"] = {
        text = L.SETTING_RESET_PINS_CONFIRM,
        button1 = YES, button2 = NO,
        OnAccept = function()
            ns:ResetAllPins()
            ns:Print(L.SETTING_RESET_PINS)
            if ns.RefreshWorldMapPins then ns:RefreshWorldMapPins() end
            if ns.RefreshPinList then ns:RefreshPinList() end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    StaticPopupDialogs["LOREPIN_RESET_SETTINGS_CONFIRM"] = {
        text = L.SETTING_RESET_SETTINGS_CONFIRM,
        button1 = YES, button2 = NO,
        OnAccept = function()
            ns:ResetSettings()
            ns:Print(L.SETTING_RESET_SETTINGS)
            if ns.RefreshSettingsControls then ns:RefreshSettingsControls() end
            if ns.RefreshWorldMapPins    then ns:RefreshWorldMapPins()    end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    local panel = CreateFrame("Frame")
    ns.settingsPanel = panel

    local title = panel:CreateFontString(nil, "ARTWORK", FONT_TITLE)
    title:SetPoint("TOPLEFT", MARGIN, TITLE_Y)
    title:SetText(ns:GetSettingsTitle())

    local y = CONTENT_Y

    local controls = {}

    -- Syncs all control values from db. Can be called on panel Show and after
    -- ResetSettings to force the UI to re-read defaults.
    local function RefreshControls()
        for _, c in ipairs(controls) do
            if c._getter and c.SetChecked then
                c:SetChecked(c._getter())
            elseif c._refreshValue then
                c._refreshValue()
            end
        end
    end
    ns.RefreshSettingsControls = RefreshControls

    -- Show on World Map
    controls[#controls + 1] = CreateCheckbox(panel, MARGIN, y, L.SETTING_SHOW_WMAP,
        function() return db.settings.showOnWorldMap end,
        function(v) db.settings.showOnWorldMap = v end,
        function() if ns.RefreshWorldMapPins then ns:RefreshWorldMapPins() end end)
    y = y - CHECKBOX_SPACING - 6

    -- World map icon size
    controls[#controls + 1] = CreateSlider(panel, MARGIN, y,
        L.SETTING_WMAP_SIZE, 10, 40, 1,
        function() return db.settings.worldMapIconSize or 20 end,
        function(v) db.settings.worldMapIconSize = v end,
        function() if ns.RefreshWorldMapPins then ns:RefreshWorldMapPins() end end)
    y = y - 48

    -- Max pins
    controls[#controls + 1] = CreateSlider(panel, MARGIN, y,
        L.SETTING_MAX_PINS, 50, 2000, 50,
        function() return db.settings.maxPins or 500 end,
        function(v) db.settings.maxPins = v end)
    y = y - 60

    -- Action buttons — consistent width for visual alignment
    local BTN_W = 220
    local BTN_H = 26

    local openListBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openListBtn:SetPoint("TOPLEFT", MARGIN, y)
    openListBtn:SetSize(BTN_W, BTN_H)
    openListBtn:SetText(L.SETTING_OPEN_LIST)
    openListBtn:SetScript("OnClick", function()
        if ns.ShowPinList then ns:ShowPinList() end
    end)
    y = y - (BTN_H + 8)

    local resetSettingsBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetSettingsBtn:SetPoint("TOPLEFT", MARGIN, y)
    resetSettingsBtn:SetSize(BTN_W, BTN_H)
    resetSettingsBtn:SetText(L.SETTING_RESET_SETTINGS)
    resetSettingsBtn:SetScript("OnClick", function()
        StaticPopup_Show("LOREPIN_RESET_SETTINGS_CONFIRM")
    end)
    y = y - (BTN_H + 8)

    local resetPinsBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetPinsBtn:SetPoint("TOPLEFT", MARGIN, y)
    resetPinsBtn:SetSize(BTN_W, BTN_H)
    resetPinsBtn:SetText(L.SETTING_RESET_PINS)
    resetPinsBtn:SetScript("OnClick", function()
        StaticPopup_Show("LOREPIN_RESET_PINS_CONFIRM")
    end)
    y = y - (BTN_H + 24)

    BuildCategorySection(panel, y)

    -- Refresh controls when panel becomes visible
    panel:SetScript("OnShow", function()
        RefreshControls()
        ns.RefreshCategorySection()
    end)

    -- Register with Blizzard settings system
    local category = Settings.RegisterCanvasLayoutCategory(panel, "LorePin")
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
end
