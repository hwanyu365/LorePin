local _, ns = ...
local L = ns.L

-- Notify other subsystems (MapRenderer, ListPanel) that pin data changed.
-- Called after successful CRUD. Silently no-ops if the subsystem isn't loaded.
local function NotifyChanged()
    if ns.RefreshWorldMapPins then ns:RefreshWorldMapPins() end
    if ns.RefreshPinList      then ns:RefreshPinList()      end
end

-- Pin record shape:
-- {
--     id         = 1,             -- unique auto-increment
--     title      = "string",      -- required
--     note       = "string",      -- optional
--     category   = "general",     -- category ID
--     mapID      = 2248,          -- C_Map.GetBestMapForUnit()
--     x          = 0.5432,        -- normalized [0,1]
--     y          = 0.3210,
--     createdAt  = 1713340800,    -- time()
--     updatedAt  = 1713340800,
--     createdBy  = "Name-Realm",  -- for account-wide context
-- }

-- Get the current player map position as (mapID, x, y) or nil on failure
function ns:GetPlayerLocation()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil, L.NO_MAP end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil, L.NO_POSITION end

    local x, y = pos:GetXY()
    if not x or not y or (x == 0 and y == 0) then
        return nil, L.NO_POSITION
    end

    return { mapID = mapID, x = x, y = y }
end

-- Creates a new pin. Returns the pin record on success, or nil + error string.
function ns:CreatePin(fields)
    if not fields or not fields.title or fields.title == "" then
        return nil, "title is required"
    end

    local maxPins = (self.db.settings and self.db.settings.maxPins) or 500
    if #self.db.pins >= maxPins then
        return nil, string.format(L.MAX_PINS_REACHED, maxPins)
    end

    local pin = {
        id        = self.db.nextPinId or 1,
        title     = fields.title,
        note      = fields.note or "",
        category  = fields.category or self:GetDefaultCategoryId(),
        mapID     = fields.mapID,
        x         = fields.x,
        y         = fields.y,
        createdAt = time(),
        updatedAt = time(),
        createdBy = UnitName("player") .. "-" .. GetRealmName(),
    }

    self.db.pins[#self.db.pins + 1] = pin
    self.db.nextPinId = pin.id + 1

    NotifyChanged()
    return pin
end

-- Create a pin at the player's current location. Title is required.
function ns:CreatePinAtPlayer(title, note, category)
    local loc, err = self:GetPlayerLocation()
    if not loc then return nil, err end

    return self:CreatePin({
        title    = title,
        note     = note,
        category = category,
        mapID    = loc.mapID,
        x        = loc.x,
        y        = loc.y,
    })
end

function ns:GetPin(pinId)
    for _, pin in ipairs(self.db.pins) do
        if pin.id == pinId then return pin end
    end
    return nil
end

-- Partial update. Only provided fields are changed. Returns true on success.
function ns:UpdatePin(pinId, fields)
    local pin = self:GetPin(pinId)
    if not pin then return false, L.PIN_NOT_FOUND end

    if fields.title    ~= nil then pin.title    = fields.title end
    if fields.note     ~= nil then pin.note     = fields.note end
    if fields.category ~= nil then pin.category = fields.category end
    if fields.mapID    ~= nil then pin.mapID    = fields.mapID end
    if fields.x        ~= nil then pin.x        = fields.x end
    if fields.y        ~= nil then pin.y        = fields.y end
    pin.updatedAt = time()

    NotifyChanged()
    return true
end

function ns:DeletePin(pinId)
    for i, pin in ipairs(self.db.pins) do
        if pin.id == pinId then
            table.remove(self.db.pins, i)
            if ns.RemovePinFromMap  then ns:RemovePinFromMap(pinId) end
            if ns.ClearTomTomForPin then ns:ClearTomTomForPin(pinId) end
            NotifyChanged()
            return true, pin
        end
    end
    return false, nil
end

function ns:GetPinsForMap(mapID)
    local result = {}
    for _, pin in ipairs(self.db.pins) do
        if pin.mapID == mapID then
            result[#result + 1] = pin
        end
    end
    return result
end

function ns:GetAllPins()
    return self.db.pins
end

function ns:GetPinCount()
    return #self.db.pins
end

-- Search pins by title/note substring (case-insensitive)
function ns:SearchPins(query)
    if not query or query == "" then return self:GetAllPins() end
    local q = query:lower()
    local result = {}
    for _, pin in ipairs(self.db.pins) do
        local title = (pin.title or ""):lower()
        local note  = (pin.note  or ""):lower()
        if title:find(q, 1, true) or note:find(q, 1, true) then
            result[#result + 1] = pin
        end
    end
    return result
end

-- ─── Waypoint / TomTom helpers ────────────────────────────────────────────────

-- Set the WoW built-in user waypoint to the given pin's location and super-track it.
function ns:SetWaypointForPin(pin)
    if not pin or not pin.mapID then return false end
    if not C_Map or not C_Map.SetUserWaypoint or not UiMapPoint then return false end

    local ok = pcall(function()
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(pin.mapID, pin.x, pin.y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end)
    return ok
end

-- Returns true if the current user waypoint matches this pin's coordinates.
-- WoW only keeps a single user waypoint at a time, so at most one pin's
-- waypoint button should show as "active" at any moment.
function ns:HasActiveWaypoint(pin)
    if not pin then return false end
    if not C_Map or not C_Map.GetUserWaypoint then return false end
    local wp = C_Map.GetUserWaypoint()
    if not wp or not wp.position then return false end
    if wp.uiMapID ~= pin.mapID then return false end
    return math.abs(wp.position.x - pin.x) < 0.001
       and math.abs(wp.position.y - pin.y) < 0.001
end

-- Toggle: if the active waypoint matches this pin, clear it; otherwise set it.
-- Returns "added", "removed", or nil on failure.
function ns:ToggleWaypointForPin(pin)
    if not pin or not pin.mapID then return nil end
    if ns:HasActiveWaypoint(pin) then
        if C_Map and C_Map.ClearUserWaypoint then
            C_Map.ClearUserWaypoint()
            return "removed"
        end
    else
        if ns:SetWaypointForPin(pin) then return "added" end
    end
    return nil
end

-- Runtime table of active TomTom waypoint UIDs, keyed by pinId.
-- Not persisted — TomTom's own saved variables track its waypoint lifecycle
-- across reloads, and our UIDs become stale after /reload anyway.
ns._tomtomUids = ns._tomtomUids or {}

function ns:IsTomTomLoaded()
    return TomTom and TomTom.AddWaypoint and TomTom.RemoveWaypoint
end

function ns:HasTomTomWaypoint(pinId)
    return ns._tomtomUids[pinId] ~= nil
end

-- Toggle a TomTom waypoint for the given pin.
-- Returns:
--   "added"   — waypoint was created
--   "removed" — waypoint was removed
--   nil, err  — TomTom not loaded
function ns:ToggleTomTomForPin(pin)
    if not pin or not pin.mapID then return nil, L.PIN_NOT_FOUND end
    if not ns:IsTomTomLoaded() then return nil, L.TOMTOM_NOT_LOADED end

    local existingUid = ns._tomtomUids[pin.id]
    if existingUid then
        pcall(function() TomTom:RemoveWaypoint(existingUid) end)
        ns._tomtomUids[pin.id] = nil
        return "removed"
    end

    -- minimap=true shows the minimap arrow, world=false suppresses TomTom's
    -- own world-map icon (avoids visual duplication with LorePin's own pin
    -- and the built-in WoW waypoint flag).
    local uid
    pcall(function()
        uid = TomTom:AddWaypoint(pin.mapID, pin.x, pin.y, {
            title   = pin.title or ("LorePin #" .. tostring(pin.id)),
            minimap = true,
            world   = false,
            from    = "LorePin",
        })
    end)

    if not uid then return nil, "TomTom waypoint creation failed" end
    ns._tomtomUids[pin.id] = uid
    return "added"
end

-- Clean up the UID table for deleted pins
function ns:ClearTomTomForPin(pinId)
    local uid = ns._tomtomUids[pinId]
    if uid and ns:IsTomTomLoaded() then
        pcall(function() TomTom:RemoveWaypoint(uid) end)
    end
    ns._tomtomUids[pinId] = nil
end
