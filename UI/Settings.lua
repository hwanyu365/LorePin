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
    title:SetText("LorePin v0.1.0")

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
    y = y - CHECKBOX_SPACING

    -- Show on Minimap
    controls[#controls + 1] = CreateCheckbox(panel, MARGIN, y, L.SETTING_SHOW_MMAP,
        function() return db.settings.showOnMinimap end,
        function(v) db.settings.showOnMinimap = v end)
    y = y - CHECKBOX_SPACING - 6

    -- World map icon size
    controls[#controls + 1] = CreateSlider(panel, MARGIN, y,
        L.SETTING_WMAP_SIZE, 10, 40, 1,
        function() return db.settings.worldMapIconSize or 20 end,
        function(v) db.settings.worldMapIconSize = v end,
        function() if ns.RefreshWorldMapPins then ns:RefreshWorldMapPins() end end)
    y = y - 48

    -- Minimap icon size
    controls[#controls + 1] = CreateSlider(panel, MARGIN, y,
        L.SETTING_MMAP_SIZE, 8, 32, 1,
        function() return db.settings.minimapIconSize or 16 end,
        function(v) db.settings.minimapIconSize = v end)
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

    -- Refresh controls when panel becomes visible
    panel:SetScript("OnShow", RefreshControls)

    -- Register with Blizzard settings system
    local category = Settings.RegisterCanvasLayoutCategory(panel, "LorePin")
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
end
