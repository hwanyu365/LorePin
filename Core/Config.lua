local _, ns = ...

local DEFAULTS = {
    pins        = {},        -- array of pin records
    nextPinId   = 1,         -- auto-increment ID
    customCategories = {},   -- user-defined categories
    settings = {
        showOnWorldMap    = true,
        showOnMinimap     = true,
        worldMapIconSize  = 20,
        minimapIconSize   = 16,
        maxPins           = 500,
    },
}

local function MergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = {}
                MergeDefaults(target[k], v)
            else
                target[k] = v
            end
        elseif type(v) == "table" and type(target[k]) == "table" then
            MergeDefaults(target[k], v)
        end
    end
end

function ns:InitDB()
    if not LorePinDB then
        LorePinDB = {}
    end
    MergeDefaults(LorePinDB, DEFAULTS)
    self.db = LorePinDB
end

function ns:ResetDB()
    wipe(LorePinDB)
    MergeDefaults(LorePinDB, DEFAULTS)
    self.db = LorePinDB
end

function ns:ResetAllPins()
    wipe(LorePinDB.pins)
    LorePinDB.nextPinId = 1
end

-- Reset only settings (not pins) to defaults
function ns:ResetSettings()
    wipe(LorePinDB.settings)
    MergeDefaults(LorePinDB.settings, DEFAULTS.settings)
end

ns.DEFAULTS = DEFAULTS
