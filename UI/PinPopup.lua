local _, ns = ...

-- New-pin popup. For editing, use DetailPanel (unified view/edit).

local dialog = nil
local MARGIN = 16

-- Pick-on-map state.
--   active       : overlay visible, waiting for user click
--   prefillTitle : title text captured from popup before it was hidden
--   prefillNote  : note text captured from popup before it was hidden
--   prefillCat   : category id captured from popup before it was hidden
local pickState = {
    active       = false,
    prefillTitle = nil,
    prefillNote  = nil,
    prefillCat   = nil,
}

-- Transparent overlay button covering the world map canvas.
-- It is only shown during pick mode to intercept mouse clicks BEFORE the map's
-- built-in drill-down / zoom-out handlers. When hidden, the map behaves normally.
local pickerOverlay = nil
local hintFrame = nil

-- Cancel pick mode and restore the popup with whatever the user had entered.
local function CancelPick(reopen)
    if not pickState.active then return end
    local savedTitle = pickState.prefillTitle
    local savedNote  = pickState.prefillNote
    local savedCat   = pickState.prefillCat
    local savedLoc   = pickState.prefillLocation

    pickState.active          = false
    pickState.prefillTitle    = nil
    pickState.prefillNote     = nil
    pickState.prefillCat      = nil
    pickState.prefillLocation = nil
    if pickerOverlay then pickerOverlay:Hide() end
    if hintFrame then hintFrame:Hide() end

    if reopen then
        ns:ShowPinPopup({
            title     = savedTitle,
            note      = savedNote,
            category  = savedCat,
            location  = savedLoc,
        })
    end
end

local function HidePicker()
    if not pickState.active then return end
    pickState.active       = false
    pickState.prefillTitle = nil
    pickState.prefillNote  = nil
    pickState.prefillCat   = nil
    pickState.prefillLocation = nil
    if pickerOverlay then pickerOverlay:Hide() end
    if hintFrame then hintFrame:Hide() end
end

function ns:InstallMapPicker()
    if ns._pickerInstalled then return end
    if not WorldMapFrame then return end

    -- Canvas is lazily created on first map show; force-open the map if
    -- necessary so we have a canvas to attach the overlay to.
    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then
        if ShowUIPanel then
            ShowUIPanel(WorldMapFrame)
        end
        canvas = WorldMapFrame:GetCanvas()
        if not canvas then return end
    end
    ns._pickerInstalled = true

    -- Overlay button (same size as canvas, parented to canvas so zoom/pan apply)
    pickerOverlay = CreateFrame("Button", "LorePinMapPickerOverlay", canvas)
    pickerOverlay:SetAllPoints(canvas)
    pickerOverlay:SetFrameStrata("HIGH")
    pickerOverlay:SetFrameLevel(canvas:GetFrameLevel() + 50)
    pickerOverlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pickerOverlay:EnableMouse(true)
    pickerOverlay:EnableKeyboard(true)
    pickerOverlay:Hide()

    -- Semi-transparent tint so user knows pick mode is active
    local tint = pickerOverlay:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints()
    tint:SetColorTexture(0.1, 0.3, 0.8, 0.10)

    -- ESC cancels pick mode and restores the popup (does NOT close the map)
    pickerOverlay:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            -- Swallow ESC so it doesn't propagate to WorldMapFrame (which would close it)
            self:SetPropagateKeyboardInput(false)
            CancelPick(true)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    pickerOverlay:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            CancelPick(true)
            return
        end

        -- Compute normalized coords from cursor
        local mapID = WorldMapFrame.mapID or WorldMapFrame:GetMapID()
        if not mapID then HidePicker(); return end

        local cx, cy = GetCursorPosition()
        local scale = canvas:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale

        local left, bottom = canvas:GetLeft(), canvas:GetBottom()
        local width, height = canvas:GetWidth(), canvas:GetHeight()
        if not left or not bottom or not width or not height then
            HidePicker()
            return
        end

        local nx = (cx - left) / width
        local ny = 1 - ((cy - bottom) / height)
        if nx < 0 or nx > 1 or ny < 0 or ny > 1 then
            HidePicker()
            return
        end

        local savedTitle = pickState.prefillTitle
        local savedNote  = pickState.prefillNote
        local savedCat   = pickState.prefillCat
        HidePicker()
        ns:ShowPinPopup({
            title    = savedTitle,
            note     = savedNote,
            category = savedCat,
            location = { mapID = mapID, x = nx, y = ny },
        })
    end)

    -- Auto-cancel when the world map closes (so the user doesn't get stuck in
    -- pick mode with a lingering overlay on next map open)
    WorldMapFrame:HookScript("OnHide", function()
        if pickState.active then
            CancelPick(true)
        end
    end)

    -- Hint label, anchored to the top of the map while pick mode is active
    hintFrame = CreateFrame("Frame", nil, WorldMapFrame, "BackdropTemplate")
    hintFrame:SetSize(400, 36)
    hintFrame:SetPoint("TOP", WorldMapFrame, "TOP", 0, -40)
    hintFrame:SetFrameStrata("HIGH")
    hintFrame:SetFrameLevel((canvas:GetFrameLevel() or 0) + 60)
    hintFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    hintFrame:SetBackdropColor(0, 0, 0, 0.85)
    hintFrame:SetBackdropBorderColor(0.4, 0.7, 1, 1)
    hintFrame.text = hintFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hintFrame.text:SetAllPoints()
    hintFrame.text:SetJustifyH("CENTER")
    hintFrame:Hide()
end

-- Begin pick mode — called from [Pick on Map] button with the popup's current fields.
-- Captures title/note/category so the popup can be reopened with the same content
-- after the user picks (or cancels).
local function StartPickMode(opts)
    opts = opts or {}

    -- Open the WorldMapFrame. ShowUIPanel is the standard WoW API to open
    -- a Blizzard panel; raw WorldMapFrame:Show() is unreliable in 12.0
    -- because the frame is gated through the UIParent panel manager.
    if WorldMapFrame and not WorldMapFrame:IsShown() then
        if ShowUIPanel then
            ShowUIPanel(WorldMapFrame)
        else
            WorldMapFrame:Show()
        end
    end

    -- Now the canvas exists; install (or no-op if already installed)
    if not ns._pickerInstalled then
        ns:InstallMapPicker()
    end
    if not pickerOverlay then
        ns:Print("Map picker unavailable.")
        return
    end

    pickState.active          = true
    pickState.prefillTitle    = opts.title
    pickState.prefillNote     = opts.note
    pickState.prefillCat      = opts.category
    pickState.prefillLocation = opts.location  -- fallback if the user cancels
    pickerOverlay:Show()
    -- Button frames receive OnKeyDown while shown + EnableKeyboard(true),
    -- no explicit focus call is needed (and Button has no SetFocus method).
    if hintFrame then
        hintFrame.text:SetText(ns.L.PICK_MODE_HINT)
        hintFrame:Show()
    end
end
ns._StartPickMode = StartPickMode

local function EnsureDialog()
    if dialog then return dialog end
    local L = ns.L
    local Layout = ns.Layout

    local f = Layout.CreateDialog("LorePinPopup", 440, 400, L.POPUP_TITLE)

    -- Row 1: Location (map name, read-only)
    local yLoc = -50
    local locLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    locLabel:SetPoint("TOPLEFT", Layout.LABEL_COL_X, yLoc)
    locLabel:SetText(L.FIELD_LOCATION)

    local mapNameText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    mapNameText:SetPoint("TOPLEFT", Layout.FIELD_VISIBLE_X, yLoc)
    mapNameText:SetPoint("RIGHT", f, "RIGHT", -Layout.MARGIN, 0)
    mapNameText:SetJustifyH("LEFT")
    f.mapNameText = mapNameText

    -- Row 2: X / Y coord inputs + action buttons.
    -- Simple frame-to-frame spacing (no chrome compensation); ensures the
    -- EditBox frame never overlaps the adjacent label.
    local yCoord = yLoc - 26
    local xLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    xLabel:SetPoint("TOPLEFT", Layout.LABEL_COL_X, yCoord - 4)
    xLabel:SetText(L.FIELD_COORD_X)

    local xEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    xEdit:SetPoint("LEFT", xLabel, "RIGHT", 10, 0)
    xEdit:SetSize(50, 22)
    xEdit:SetAutoFocus(false)
    xEdit:SetMaxLetters(6)
    xEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.xEdit = xEdit

    local yLabelFs = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    yLabelFs:SetPoint("LEFT", xEdit, "RIGHT", 8, 0)
    yLabelFs:SetText(L.FIELD_COORD_Y)

    local yEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    yEdit:SetPoint("LEFT", yLabelFs, "RIGHT", 10, 0)
    yEdit:SetSize(50, 22)
    yEdit:SetAutoFocus(false)
    yEdit:SetMaxLetters(6)
    yEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.yEdit = yEdit

    -- Action buttons anchored to right edge
    local pickBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    pickBtn:SetSize(110, 22)
    pickBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -Layout.MARGIN, yCoord - 2)
    pickBtn:SetText(L.BTN_PICK_FROM_MAP)
    f.pickBtn = pickBtn

    local currentBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    currentBtn:SetSize(80, 22)
    currentBtn:SetPoint("RIGHT", pickBtn, "LEFT", -Layout.BTN_GAP, 0)
    currentBtn:SetText(L.BTN_USE_PLAYER_POS)
    f.currentBtn = currentBtn

    -- Row 3: Title
    local _, titleEdit, nextY = Layout.AddEditBoxRow(f, yCoord - 32, L.FIELD_TITLE,
        { maxLetters = 120 })
    f.titleEdit = titleEdit

    -- Row 4: Category — dropdown's visible left edge aligns with titleEdit's.
    -- nextY already incorporates ROW_H (32), so use it directly for uniform spacing.
    local _, dropdown = Layout.AddDropdownRowAlignedWithEdit(f, nextY,
        L.FIELD_CATEGORY, titleEdit, "LorePinPopupCatDropdown", 160)
    f.dropdown = dropdown
    f.selectedCategory = "general"

    local function UpdateDropdownText()
        local cat = ns:GetCategoryById(f.selectedCategory)
        UIDropDownMenu_SetText(dropdown, cat and cat.name or f.selectedCategory)
    end
    f.UpdateDropdownText = UpdateDropdownText

    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, cat in ipairs(ns:GetCategories()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text    = cat.name
            info.value   = cat.id
            info.checked = (f.selectedCategory == cat.id)
            info.func    = function(btn)
                f.selectedCategory = btn.value
                UpdateDropdownText()
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Row 5: Note (multiline, full width)
    -- Extra breathing room between the dropdown row and the note label
    local _, noteEdit = Layout.AddMultilineRow(f, nextY - Layout.ROW_H - 10,
        L.FIELD_NOTE, 140, { maxLetters = 500 })
    f.noteEdit = noteEdit

    -- Bottom buttons: [Save] [Cancel] right-aligned
    local buttons = Layout.CreateButtonRow(f, {
        { key = "save",   text = L.BUTTON_SAVE },
        { key = "cancel", text = L.BUTTON_CANCEL, onClick = function() f:Hide() end },
    })
    f.saveButton = buttons.save

    dialog = f
    return f
end

-- Sync the location fields (mapName, x, y) based on a location table
local function ApplyLocation(f, loc)
    f._location = loc
    local mapInfo = C_Map.GetMapInfo(loc.mapID)
    local mapName = (mapInfo and mapInfo.name) or ("Map " .. tostring(loc.mapID))
    f.mapNameText:SetText(mapName)
    f.xEdit:SetText(string.format("%.1f", (loc.x or 0) * 100))
    f.yEdit:SetText(string.format("%.1f", (loc.y or 0) * 100))
end

-- Options:
--   opts.location  -- pre-fill {mapID,x,y}; falls back to current player location
--   opts.title     -- pre-fill title
--   opts.note      -- pre-fill note
--   opts.category  -- pre-fill category id
--   opts.onSaved(pin)
function ns:ShowPinPopup(opts)
    opts = opts or {}
    local L = self.L
    local f = EnsureDialog()

    -- Reset fields
    f.titleEdit:SetText("")
    f.noteEdit:SetText("")
    f.selectedCategory = self:GetDefaultCategoryId()
    f.UpdateDropdownText()
    f.title:SetText(L.POPUP_TITLE)

    if opts.title    then f.titleEdit:SetText(opts.title) end
    if opts.note     then f.noteEdit:SetText(opts.note)   end
    if opts.category then
        f.selectedCategory = opts.category
        f.UpdateDropdownText()
    end

    -- Determine location
    local loc
    if opts.location then
        loc = opts.location
    else
        local playerLoc, err = self:GetPlayerLocation()
        if not playerLoc then
            self:Print(err or L.NO_POSITION)
            return
        end
        loc = playerLoc
    end
    ApplyLocation(f, loc)

    -- [Current] re-fills with player location
    f.currentBtn:SetScript("OnClick", function()
        local playerLoc, err = self:GetPlayerLocation()
        if not playerLoc then
            self:Print(err or L.NO_POSITION)
            return
        end
        ApplyLocation(f, playerLoc)
    end)

    -- [Pick on Map] switches to selection mode. The popup closes; the
    -- overlay intercepts the next map click. All field values are captured
    -- so the popup can be reopened with them intact after pick (or cancel).
    f.pickBtn:SetScript("OnClick", function()
        local captured = {
            title    = f.titleEdit:GetText(),
            note     = f.noteEdit:GetText(),
            category = f.selectedCategory,
            location = f._location,
        }
        f:Hide()
        if ns._StartPickMode then ns._StartPickMode(captured) end
    end)

    -- Save: validate coords + title, then create
    f.saveButton:SetScript("OnClick", function()
        local title = f.titleEdit:GetText() or ""
        if title == "" then
            self:Print(L.TITLE_REQUIRED)
            return
        end

        -- Parse coordinates (user input is in 0..100 scale)
        local xRaw = tonumber(f.xEdit:GetText())
        local yRaw = tonumber(f.yEdit:GetText())
        if not xRaw or not yRaw or xRaw < 0 or xRaw > 100 or yRaw < 0 or yRaw > 100 then
            self:Print(L.INVALID_COORDINATES)
            return
        end

        local pin, err = self:CreatePin({
            title    = title,
            note     = f.noteEdit:GetText() or "",
            category = f.selectedCategory,
            mapID    = f._location.mapID,
            x        = xRaw / 100,
            y        = yRaw / 100,
        })
        if not pin then
            self:Print(err or "Failed to create pin")
            return
        end
        self:Print(string.format(L.PIN_CREATED, title))
        if opts.onSaved then opts.onSaved(pin) end
        f:Hide()
    end)

    f:Show()
end
