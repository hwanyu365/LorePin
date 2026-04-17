local _, ns = ...

-- Unified detail/edit panel for an existing pin.
-- Fields are always rendered as editable controls; buttons change behavior
-- based on whether there are unsaved changes.
--
-- Button states:
--   Clean (no unsaved changes): [Waypoint] [Delete] [Close]
--   Dirty (unsaved changes):    [Save] [Discard] [Close]
-- Waypoint/Delete are disabled while the user has unsaved edits, since the
-- buttons would operate on the last-saved state and confuse the user.

local panel = nil
local MARGIN = 16

-- StaticPopups (registered once)
StaticPopupDialogs["LOREPIN_CONFIRM_DELETE"] = {
    text = "",
    button1 = YES, button2 = NO,
    OnAccept = function(self, data)
        if not data or not data.pinId then return end
        local ok, pin = ns:DeletePin(data.pinId)
        if ok then
            ns:Print(string.format(ns.L.PIN_DELETED, pin.title or ""))
            if data.onDeleted then data.onDeleted() end
        else
            ns:Print(ns.L.PIN_NOT_FOUND)
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["LOREPIN_CONFIRM_DISCARD"] = {
    text = "",
    button1 = YES, button2 = NO,
    OnAccept = function(_, data)
        if data and data.onDiscard then data.onDiscard() end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function EnsurePanel()
    if panel then return panel end
    local L = ns.L
    local Layout = ns.Layout

    local f = Layout.CreateDialog("LorePinDetailPanel", 440, 400, L.DETAIL_TITLE)

    -- Dirty marker in the title bar
    f.dirtyMarker = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.dirtyMarker:SetPoint("LEFT", f.title, "RIGHT", 6, 0)
    f.dirtyMarker:SetTextColor(1, 0.82, 0)
    f.dirtyMarker:SetText("*")
    f.dirtyMarker:Hide()

    -- DetailPanel has a large category icon on the left, which shifts labels
    -- and fields to the right compared to PinPopup. We use local overrides
    -- that follow the same chrome-offset rules as Layout.
    local ICON_SIZE       = Layout.ICON_SIZE
    local LABEL_COL_X     = Layout.MARGIN + ICON_SIZE + 10
    local FIELD_VISIBLE_X = LABEL_COL_X + 60
    local ROW_H           = Layout.ROW_H   -- 32 (same as PinPopup)

    local yTop = -50

    -- Large category icon vertically centered across title + category rows.
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("TOPLEFT", Layout.MARGIN, yTop - 8)
    f.icon = icon

    -- Row 1: Title (label + edit)
    -- Label y-offset = LABEL_Y_FOR_EDITBOX so label center = editbox center
    local titleLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT", LABEL_COL_X, yTop + Layout.LABEL_Y_FOR_EDITBOX)
    titleLabel:SetText(L.FIELD_TITLE)

    local titleEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    titleEdit:SetPoint("TOPLEFT", FIELD_VISIBLE_X + Layout.EDITBOX_OFFSET, yTop - 2)
    titleEdit:SetPoint("RIGHT", f, "RIGHT", -Layout.MARGIN, 0)
    titleEdit:SetHeight(22)
    titleEdit:SetAutoFocus(false)
    titleEdit:SetMaxLetters(120)
    titleEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.titleEdit = titleEdit

    -- Row 2: Category (label + dropdown).
    -- Dropdown's visible-left edge is aligned to titleEdit's via relative anchor.
    -- Label y-offset = LABEL_Y_FOR_DROPDOWN so label center = dropdown center.
    local yRow2 = yTop - ROW_H
    local catLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    catLabel:SetPoint("TOPLEFT", LABEL_COL_X, yRow2 + Layout.LABEL_Y_FOR_DROPDOWN)
    catLabel:SetText(L.FIELD_CATEGORY)

    local dropdown = CreateFrame("Frame", "LorePinDetailCatDropdown", f, "UIDropDownMenuTemplate")
    local alignOffset = Layout.DROPDOWN_OFFSET - Layout.EDITBOX_OFFSET
    dropdown:SetPoint("LEFT", titleEdit, "LEFT", alignOffset, 0)
    dropdown:SetPoint("TOP", f, "TOP", 0, yRow2 + 2)
    UIDropDownMenu_SetWidth(dropdown, 160)
    f.dropdown = dropdown
    f.selectedCategory = "general"

    local function UpdateDropdownText()
        local cat = ns:GetCategoryById(f.selectedCategory)
        UIDropDownMenu_SetText(dropdown, cat and cat.name or f.selectedCategory)
    end
    f.UpdateDropdownText = UpdateDropdownText

    -- Row 3: Note label + multi-line field. Positioned well below the
    -- category row; extra ~16px of breathing room so the note label doesn't
    -- hug the category dropdown.
    local yNote = yTop - (ICON_SIZE + 44)
    local _, noteEdit, noteBg = Layout.AddMultilineRow(f, yNote, L.FIELD_NOTE, 130,
        { maxLetters = 500 })
    f.noteEdit = noteEdit

    -- Metadata readonly rows — anchored to note box bottom so they follow the
    -- multi-line field's size.
    local locText = f:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    locText:SetPoint("TOPLEFT", noteBg, "BOTTOMLEFT", 0, -8)
    f.locText = locText

    local createdText = f:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    createdText:SetPoint("TOPLEFT", locText, "BOTTOMLEFT", 0, -2)
    f.createdText = createdText

    local authorText = f:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    authorText:SetPoint("TOPLEFT", createdText, "BOTTOMLEFT", 0, -2)
    f.authorText = authorText

    -- Clean-state button row: [Waypoint] [TomTom] [Delete] [Close]
    local cleanBtns = Layout.CreateButtonRow(f, {
        { key = "waypoint", text = L.BUTTON_WAYPOINT },
        { key = "tomtom",   text = L.BUTTON_TOMTOM },
        { key = "delete",   text = L.BUTTON_DELETE },
        { key = "close",    text = L.BUTTON_CLOSE },
    })
    f.btnWaypoint = cleanBtns.waypoint
    f.btnTomTom   = cleanBtns.tomtom
    f.btnDelete   = cleanBtns.delete
    f.btnClose    = cleanBtns.close

    -- Dirty-state buttons occupy same x slots as Close / Delete.
    -- Save anchors LEFT of discard (like the original layout).
    local btnDiscard = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnDiscard:SetSize(Layout.BTN_W, Layout.BTN_H)
    btnDiscard:SetPoint("RIGHT", f.btnClose, "LEFT", -Layout.BTN_GAP, 0)
    btnDiscard:SetText(L.BUTTON_CANCEL)
    btnDiscard:Hide()
    f.btnDiscard = btnDiscard

    local btnSave = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnSave:SetSize(Layout.BTN_W, Layout.BTN_H)
    btnSave:SetPoint("RIGHT", btnDiscard, "LEFT", -Layout.BTN_GAP, 0)
    btnSave:SetText(L.BUTTON_SAVE)
    btnSave:Hide()
    f.btnSave = btnSave

    panel = f
    return f
end

-- Apply current field values to visual state based on dirty flag
local function RefreshDirtyState(f)
    if f.isDirty then
        f.dirtyMarker:Show()
        f.btnDelete:Hide()
        f.btnWaypoint:Hide()
        f.btnTomTom:Hide()
        f.btnSave:Show()
        f.btnDiscard:Show()
    else
        f.dirtyMarker:Hide()
        f.btnSave:Hide()
        f.btnDiscard:Hide()
        f.btnDelete:Show()
        f.btnWaypoint:Show()
        f.btnTomTom:Show()
    end
end

-- Compare current field values to original to determine dirty status
local function ComputeDirty(f)
    if not f.originalPin then return false end
    if (f.titleEdit:GetText() or "") ~= (f.originalPin.title or "") then return true end
    if (f.noteEdit:GetText() or "") ~= (f.originalPin.note or "") then return true end
    if f.selectedCategory ~= (f.originalPin.category or "") then return true end
    return false
end

local function UpdateDirtyFromFields(f)
    f.isDirty = ComputeDirty(f)
    RefreshDirtyState(f)
end

-- Public: show the detail panel for a pin by ID
function ns:ShowPinDetail(pinId)
    local L = self.L
    local pin = self:GetPin(pinId)
    if not pin then
        self:Print(L.PIN_NOT_FOUND)
        return
    end

    local f = EnsurePanel()
    f.currentPinId = pin.id
    f.originalPin = {
        title    = pin.title    or "",
        note     = pin.note     or "",
        category = pin.category or self:GetDefaultCategoryId(),
    }
    f.isDirty = false

    -- Mark-dirty helper used by dropdown
    function f:MarkDirty()
        UpdateDirtyFromFields(self)
    end

    -- Icon preview reflects current selected category, not saved
    local function RefreshIcon()
        local cat = ns:GetCategoryById(f.selectedCategory)
        if cat then
            f.icon:SetTexture(cat.icon)
            f.icon:SetVertexColor(cat.color.r, cat.color.g, cat.color.b, 1.0)
        else
            f.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            f.icon:SetVertexColor(1, 1, 1, 1)
        end
    end

    -- Wire field change detection (re-run on every keystroke/menu select)
    f.titleEdit:SetScript("OnTextChanged", function() UpdateDirtyFromFields(f) end)
    f.noteEdit:SetScript("OnTextChanged", function() UpdateDirtyFromFields(f) end)

    -- Populate fields
    f.titleEdit:SetText(pin.title or "")
    f.noteEdit:SetText(pin.note or "")
    f.selectedCategory = pin.category or self:GetDefaultCategoryId()
    f.UpdateDropdownText()
    RefreshIcon()

    -- Metadata
    local mapInfo = C_Map.GetMapInfo(pin.mapID or 0)
    local mapName = (mapInfo and mapInfo.name) or ("Map " .. tostring(pin.mapID))
    f.locText:SetText(string.format("%s  (%.1f, %.1f)",
        mapName, (pin.x or 0) * 100, (pin.y or 0) * 100))
    f.createdText:SetText(string.format("%s: %s",
        L.CREATED_AT, date("%Y-%m-%d %H:%M", pin.createdAt or 0)))
    f.authorText:SetText(string.format("%s: %s",
        L.CREATED_BY, pin.createdBy or "-"))

    -- Override dropdown callback so icon also refreshes when category changes
    UIDropDownMenu_Initialize(f.dropdown, function(_, level)
        for _, cat in ipairs(ns:GetCategories()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text    = cat.name
            info.value   = cat.id
            info.checked = (f.selectedCategory == cat.id)
            info.func    = function(btn)
                f.selectedCategory = btn.value
                f.UpdateDropdownText()
                RefreshIcon()
                CloseDropDownMenus()
                UpdateDirtyFromFields(f)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Save button: persist changes, re-sync view
    f.btnSave:SetScript("OnClick", function()
        local title = f.titleEdit:GetText() or ""
        if title == "" then
            ns:Print(L.TITLE_REQUIRED)
            return
        end
        ns:UpdatePin(pin.id, {
            title    = title,
            note     = f.noteEdit:GetText() or "",
            category = f.selectedCategory,
        })
        ns:Print(string.format(L.PIN_UPDATED, title))

        -- Re-read from DB (pin fields updated in-place by PinManager)
        f.originalPin.title    = title
        f.originalPin.note     = f.noteEdit:GetText() or ""
        f.originalPin.category = f.selectedCategory
        f.isDirty = false
        RefreshDirtyState(f)
    end)

    -- Discard button: revert to original
    f.btnDiscard:SetScript("OnClick", function()
        f.titleEdit:SetText(f.originalPin.title)
        f.noteEdit:SetText(f.originalPin.note)
        f.selectedCategory = f.originalPin.category
        f.UpdateDropdownText()
        RefreshIcon()
        f.isDirty = false
        RefreshDirtyState(f)
    end)

    -- Delete
    f.btnDelete:SetScript("OnClick", function()
        local dialog = StaticPopupDialogs["LOREPIN_CONFIRM_DELETE"]
        dialog.text = L.CONFIRM_DELETE
        StaticPopup_Show("LOREPIN_CONFIRM_DELETE", nil, nil, {
            pinId = pin.id,
            onDeleted = function() f:Hide() end,
        })
    end)

    -- Waypoint toggle — same behavior as the list panel's row button.
    local function RefreshWaypointHighlight()
        if ns:HasActiveWaypoint(pin) then
            f.btnWaypoint:LockHighlight()
        else
            f.btnWaypoint:UnlockHighlight()
        end
    end
    RefreshWaypointHighlight()

    f.btnWaypoint:SetScript("OnClick", function()
        ns:ToggleWaypointForPin(pin)
        RefreshWaypointHighlight()
        if ns.RefreshWaypointButtons then ns:RefreshWaypointButtons() end
    end)

    -- TomTom toggle (disabled when the TomTom addon isn't installed)
    local function RefreshTomTomHighlight()
        if not ns:IsTomTomLoaded() then
            f.btnTomTom:Disable()
            f.btnTomTom:SetAlpha(0.5)
            f.btnTomTom:UnlockHighlight()
            return
        end
        f.btnTomTom:Enable()
        f.btnTomTom:SetAlpha(1.0)
        if ns:HasTomTomWaypoint(pin.id) then
            f.btnTomTom:LockHighlight()
        else
            f.btnTomTom:UnlockHighlight()
        end
    end
    RefreshTomTomHighlight()

    f.btnTomTom:SetScript("OnClick", function()
        local result, err = ns:ToggleTomTomForPin(pin)
        if not result and err then ns:Print(err); return end
        RefreshTomTomHighlight()
    end)

    -- Close with unsaved confirmation
    local function AttemptClose()
        if f.isDirty then
            local d = StaticPopupDialogs["LOREPIN_CONFIRM_DISCARD"]
            d.text = L.DISCARD_CONFIRM
            StaticPopup_Show("LOREPIN_CONFIRM_DISCARD", nil, nil, {
                onDiscard = function()
                    f.isDirty = false
                    f:Hide()
                end,
            })
        else
            f:Hide()
        end
    end
    f.btnClose:SetScript("OnClick", AttemptClose)
    f.closeBtn:SetScript("OnClick", AttemptClose)

    RefreshDirtyState(f)
    f:Show()
end

