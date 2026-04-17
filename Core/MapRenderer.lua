local _, ns = ...

-- World map pin renderer
-- Attaches pin frames to WorldMapFrame's canvas. Canvas handles zoom/pan
-- automatically via frame parenting; we only need to position each pin in
-- normalized (0..1) coordinates scaled by canvas dimensions.

local pinFrames = {}  -- [pinId] = Button frame
local hooksInstalled = false

local function FormatCoords(pin)
    return string.format("(%.1f, %.1f)", (pin.x or 0) * 100, (pin.y or 0) * 100)
end

-- Build a |cff<RRGGBB>...|r-wrapped color escape from 0..1 RGB values.
local function Colored(text, r, g, b)
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor((r or 1) * 255),
        math.floor((g or 1) * 255),
        math.floor((b or 1) * 255),
        text or "")
end

local function OnPinEnter(self)
    local pin = self.pinData
    if not pin then return end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    -- Embed color directly in the string. This works reliably regardless of
    -- how GameTooltip handles r/g/b arguments or post-Show() overrides.
    GameTooltip:AddLine(Colored(pin.title or "", 1, 1, 1))

    local cat = ns:GetCategoryById(pin.category)
    if cat then
        GameTooltip:AddLine(Colored(cat.name, cat.color.r, cat.color.g, cat.color.b))
    end

    if pin.note and pin.note ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(Colored(pin.note, 0.9, 0.9, 0.9), nil, nil, nil, true)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(Colored(FormatCoords(pin), 0.6, 0.6, 0.6))

    GameTooltip:Show()

    -- Force every line to the same font so title, category, note and coords
    -- render at identical size (AddLine otherwise picks header-style for L1).
    for i = 1, GameTooltip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        if line then line:SetFontObject("GameTooltipText") end
    end
end

local function OnPinLeave(self)
    GameTooltip:Hide()
end

local function OnPinClick(self, button)
    local pin = self.pinData
    if not pin then return end
    if ns.ShowPinDetail then
        ns:ShowPinDetail(pin.id)
    else
        ns:Print(string.format("[%d] %s", pin.id, pin.title or ""))
    end
end

local function CreatePinFrame(parent)
    local frame = CreateFrame("Button", nil, parent)
    frame:SetSize(20, 20)
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local tex = frame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    frame.texture = tex

    -- Subtle backdrop halo for visibility over map
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("CENTER")
    bg:SetSize(22, 22)
    bg:SetColorTexture(0, 0, 0, 0.4)
    frame.bg = bg

    frame:SetScript("OnEnter", OnPinEnter)
    frame:SetScript("OnLeave", OnPinLeave)
    frame:SetScript("OnClick", OnPinClick)

    return frame
end

local function PositionPin(frame, canvas, pin)
    local w, h = canvas:GetSize()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", canvas, "TOPLEFT", (pin.x or 0) * w, -(pin.y or 0) * h)
end

-- Hide all pin frames (but keep them cached for reuse)
local function HideAllPins()
    for _, frame in pairs(pinFrames) do
        frame:Hide()
    end
end

function ns:RefreshWorldMapPins()
    HideAllPins()

    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
    if not self.db or not self.db.settings.showOnWorldMap then return end

    local mapID = WorldMapFrame.mapID or WorldMapFrame:GetMapID()
    if not mapID then return end

    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then return end

    local iconSize = self.db.settings.worldMapIconSize or 20

    for _, pin in ipairs(self:GetPinsForMap(mapID)) do
        local frame = pinFrames[pin.id]
        if not frame then
            frame = CreatePinFrame(canvas)
            pinFrames[pin.id] = frame
        else
            frame:SetParent(canvas)
        end

        frame.pinData = pin
        frame:SetSize(iconSize, iconSize)
        frame.bg:SetSize(iconSize + 2, iconSize + 2)

        local cat = self:GetCategoryById(pin.category)
        if cat then
            frame.texture:SetTexture(cat.icon)
            -- Light tint: avoid over-saturating icons by keeping alpha 1.0
            frame.texture:SetVertexColor(cat.color.r, cat.color.g, cat.color.b, 1.0)
        else
            frame.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            frame.texture:SetVertexColor(1, 1, 1, 1)
        end

        PositionPin(frame, canvas, pin)
        frame:Show()
    end
end

-- Remove cached frame for a deleted pin
function ns:RemovePinFromMap(pinId)
    local frame = pinFrames[pinId]
    if frame then
        frame:Hide()
        frame:SetParent(nil)
        frame.pinData = nil
        pinFrames[pinId] = nil
    end
end

-- Install hooks to refresh when map opens/changes
function ns:InstallMapHooks()
    if hooksInstalled then return end
    if not WorldMapFrame then return end

    WorldMapFrame:HookScript("OnShow", function()
        ns:RefreshWorldMapPins()
    end)

    -- OnMapChanged fires when the player changes the viewed map
    if WorldMapFrame.OnMapChanged then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            ns:RefreshWorldMapPins()
        end)
    end

    hooksInstalled = true
end
