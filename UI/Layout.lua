local _, ns = ...

-- ─── Layout helpers ──────────────────────────────────────────────────────────
-- Centralized grid/spacing/widget-chrome constants + factory functions for the
-- dialogs and panels in this addon. All new UI should go through these so
-- alignment, offsets and button state are handled consistently.
--
-- Documented in CLAUDE.md "UI Development Guidelines".

local Layout = {}
ns.Layout = Layout

-- ─── Constants ───────────────────────────────────────────────────────────────

Layout.MARGIN           = 16     -- panel outer padding
Layout.ROW_H            = 32     -- vertical spacing between form rows
Layout.LABEL_COL_X      = 16     -- x of all form labels
Layout.FIELD_VISIBLE_X  = 86     -- x of visible left edge for all form inputs
Layout.ICON_SIZE        = 40     -- square size for large category-icon previews

-- Label y-offset relative to row baseline. Labels are TOP-anchored, and we
-- need them to line up with the vertical CENTER of their paired control.
-- Font height ~14 → label center = label_top - 7.
--   EditBox (height 22, top = y - 2):  center = y - 13 → label_top = y - 6
--   Dropdown (height 32, top = y + 2): center = y - 14 → label_top = y - 7
Layout.LABEL_Y_FOR_EDITBOX  = -6
Layout.LABEL_Y_FOR_DROPDOWN = -7

-- Per-widget chrome offsets. WoW widgets have invisible padding/chrome at
-- their edges. To make the VISIBLE left edge line up with FIELD_VISIBLE_X,
-- we subtract each widget's chrome from its anchor x:
--
-- InputBoxTemplate: Left texture IS the visible border (not transparent
-- chrome), so frame_left == visible_left. Offset = 0.
--
-- UIDropDownMenuTemplate: Left texture contains transparent chrome on its
-- left half; the visible "box" of the dropdown starts ~17px into the frame.
-- Offset = -17 so that anchoring at FIELD_VISIBLE_X + (-17) places the
-- visible box at FIELD_VISIBLE_X.
-- InputBoxTemplate's Left texture is anchored at x=-5 from the frame, so its
-- VISIBLE left edge is 5px further left than frame:GetLeft(). To make the
-- visible edge land at FIELD_VISIBLE_X we need EDITBOX_OFFSET = +5.
Layout.EDITBOX_OFFSET           = 5
Layout.EDITBOX_RIGHT_OFFSET     = -5    -- symmetric right-side
-- UIDropDownMenuTemplate's Left texture contains a transparent shadow
-- (~15px) followed by the visible box border. Users perceive the box border
-- as the visible left edge, which is roughly at frame.left + 15.
-- The RIGHT side includes the visible arrow/border, so visible right is
-- essentially at frame.right (no chrome offset needed).
Layout.DROPDOWN_OFFSET          = -17
Layout.DROPDOWN_RIGHT_OFFSET    = 12

-- Buttons
Layout.BTN_W   = 80
Layout.BTN_H   = 24
Layout.BTN_GAP = 6

-- ─── Backdrop + dialog shell ─────────────────────────────────────────────────

function Layout.ApplyDialogBackdrop(f)
    f:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        edgeSize = 26,
        insets   = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
end

-- Create a movable, toplevel dialog with a title and a close button.
-- Returns the frame. Access `f.title` (FontString) and `f.closeBtn` (Button).
function Layout.CreateDialog(name, w, h, titleText)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    Layout.ApplyDialogBackdrop(f)
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -14)
    f.title:SetText(titleText or "")

    -- UIPanelCloseButton has its own chrome (~8px on each side). Pushing it
    -- a bit further inside (-10, -10) keeps the visible X within the panel
    -- border nicely rather than straddling the edge.
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -10, -10)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    f.closeBtn = closeBtn

    return f
end

-- ─── Form rows ───────────────────────────────────────────────────────────────

local function CreateLabel(parent, x, y, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text or "")
    return fs
end

-- Label + single-line EditBox row. EditBox stretches to panel RIGHT - MARGIN.
-- Label is vertically centered on the EditBox.
-- Options:
--   opts.maxLetters
--   opts.numeric     -- if true, restrict to numeric input
--   opts.width       -- fixed EditBox width (overrides stretch-to-right)
-- Returns (label, editBox, nextY)
function Layout.AddEditBoxRow(parent, y, labelText, opts)
    opts = opts or {}
    local label = CreateLabel(parent, Layout.LABEL_COL_X, y + Layout.LABEL_Y_FOR_EDITBOX, labelText)

    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetPoint("TOPLEFT", Layout.FIELD_VISIBLE_X + Layout.EDITBOX_OFFSET, y - 2)
    if opts.width then
        edit:SetWidth(opts.width)
    else
        edit:SetPoint("RIGHT", parent, "RIGHT", -Layout.MARGIN, 0)
    end
    edit:SetHeight(22)
    edit:SetAutoFocus(false)
    if opts.maxLetters then edit:SetMaxLetters(opts.maxLetters) end
    if opts.numeric    then edit:SetNumeric(true) end
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    return label, edit, y - Layout.ROW_H
end

-- Label + Dropdown row (visible-left edge aligned with FIELD_VISIBLE_X).
-- Label is vertically centered on the Dropdown.
-- Returns (label, dropdown, nextY)
function Layout.AddDropdownRow(parent, y, labelText, dropdownName, width)
    local label = CreateLabel(parent, Layout.LABEL_COL_X, y + Layout.LABEL_Y_FOR_DROPDOWN, labelText)

    local dropdown = CreateFrame("Frame", dropdownName, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", Layout.FIELD_VISIBLE_X + Layout.DROPDOWN_OFFSET, y + 2)
    UIDropDownMenu_SetWidth(dropdown, width or 160)

    return label, dropdown, y - Layout.ROW_H
end

-- Label + Dropdown row whose VISIBLE left edge is aligned to a reference
-- EditBox's visible left edge. Use this when you want a title EditBox above
-- and a category dropdown below to line up precisely, regardless of whether
-- EDITBOX_OFFSET / DROPDOWN_OFFSET are exactly right in absolute terms.
--
-- Derivation:
--   editbox_visible_x  = editbox:GetLeft() - EDITBOX_OFFSET   (offset is negative)
--   dropdown_visible_x = dropdown:GetLeft() - DROPDOWN_OFFSET
-- Setting them equal:
--   dropdown:GetLeft() = editbox:GetLeft() + (DROPDOWN_OFFSET - EDITBOX_OFFSET)
-- Example: EB=-8, DD=-17  ->  dropdown anchored at editbox:LEFT with offset -9
--
-- Returns (label, dropdown, nextY)
function Layout.AddDropdownRowAlignedWithEdit(parent, y, labelText, referenceEdit, dropdownName, width)
    local label = CreateLabel(parent, Layout.LABEL_COL_X, y + Layout.LABEL_Y_FOR_DROPDOWN, labelText)

    local dropdown = CreateFrame("Frame", dropdownName, parent, "UIDropDownMenuTemplate")
    local alignOffset = Layout.DROPDOWN_OFFSET - Layout.EDITBOX_OFFSET
    dropdown:SetPoint("LEFT", referenceEdit, "LEFT", alignOffset, 0)
    -- Vertical position: anchor dropdown's TOP to parent's TOP (y is negative)
    dropdown:SetPoint("TOP", parent, "TOP", 0, y + 2)
    UIDropDownMenu_SetWidth(dropdown, width or 160)

    return label, dropdown, y - Layout.ROW_H
end

-- Full-width multi-line text area. Label sits above (at LABEL_COL_X), field
-- spans panel width. Returns (label, editBox, backdropFrame, nextY).
function Layout.AddMultilineRow(parent, y, labelText, height, opts)
    opts = opts or {}
    height = height or 110

    local label = CreateLabel(parent, Layout.MARGIN, y, labelText)

    local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", Layout.MARGIN, y - 18)
    bg:SetPoint("RIGHT", parent, "RIGHT", -Layout.MARGIN, 0)
    bg:SetHeight(height)
    bg:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    bg:SetBackdropColor(0, 0, 0, 0.5)
    bg:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    -- Inset the scroll area so the scrollbar chrome stays inside the backdrop
    -- border (the scrollbar is anchored to the right of the ScrollFrame).
    local scroll = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(scroll:GetWidth() or 350)
    if opts.maxLetters then edit:SetMaxLetters(opts.maxLetters) end
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(edit)

    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function() edit:SetFocus() end)

    return label, edit, bg, y - 18 - height
end

-- ─── Button helpers ──────────────────────────────────────────────────────────

-- Create a bottom-right button row from a spec list.
-- specs = { {key="save", text="Save", onClick=fn}, ... }
-- The LAST spec ends up rightmost (at BOTTOMRIGHT - MARGIN); earlier specs
-- sit to its left. Returns a map { key = button, ... }.
function Layout.CreateButtonRow(parent, specs, bottomOffset)
    bottomOffset = bottomOffset or 16
    local result = {}
    local prev
    for i = #specs, 1, -1 do
        local spec = specs[i]
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(spec.width or Layout.BTN_W, spec.height or Layout.BTN_H)
        if not prev then
            btn:SetPoint("BOTTOMRIGHT", -Layout.MARGIN, bottomOffset)
        else
            btn:SetPoint("RIGHT", prev, "LEFT", -Layout.BTN_GAP, 0)
        end
        btn:SetText(spec.text or "")
        if spec.onClick then btn:SetScript("OnClick", spec.onClick) end
        if spec.key then result[spec.key] = btn end
        prev = btn
    end
    return result
end

-- Toggle visual state of a UIPanelButton safely (UIPanelButtonTemplate has
-- no reliable NormalTexture). When inactive: dim via alpha + text color.
function Layout.SetButtonActive(btn, active, activeColor, inactiveColor)
    if active then
        btn:LockHighlight()
        btn:SetAlpha(1.0)
        if activeColor then
            local fs = btn:GetFontString()
            if fs then fs:SetTextColor(activeColor.r, activeColor.g, activeColor.b) end
        end
    else
        btn:UnlockHighlight()
        btn:SetAlpha(0.55)
        if inactiveColor then
            local fs = btn:GetFontString()
            if fs then fs:SetTextColor(inactiveColor.r, inactiveColor.g, inactiveColor.b) end
        end
    end
end

-- Fully enable/disable a button (unclickable when disabled).
function Layout.SetButtonDisabled(btn, disabled)
    if disabled then
        btn:Disable()
        btn:SetAlpha(0.5)
    else
        btn:Enable()
        btn:SetAlpha(1.0)
    end
end

-- Arrange a list of buttons in a single row with equal widths spanning the
-- full width of a container. Useful for filter button rows.
function Layout.EquallyDistributeButtons(container, buttons, gap)
    gap = gap or 4
    local n = #buttons
    if n == 0 then return end

    -- Prefer container's own width; fall back to parent width minus margins.
    -- If the container is two-point anchored, its width may not resolve
    -- until after Show().
    local totalW = container:GetWidth()
    if not totalW or totalW < 50 then
        local parent = container:GetParent()
        if parent and parent:GetWidth() then
            totalW = parent:GetWidth() - 2 * Layout.MARGIN
        else
            totalW = 500
        end
    end

    local btnW = math.floor((totalW - gap * (n - 1)) / n)
    local prev
    for _, btn in ipairs(buttons) do
        btn:ClearAllPoints()
        btn:SetWidth(btnW)
        if not prev then
            btn:SetPoint("LEFT", container, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", prev, "RIGHT", gap, 0)
        end
        prev = btn
    end
end
