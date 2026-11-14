-- usage (테스트 파일 안): local support = load_source("scripts/test-support.lua")
-- 테스트 환경 전역에 WoW API 대역을 넣고, TOC 순서대로 Core 파일을 불러온 ns 를 돌려준다.
-- 매 호출마다 새 ns·새 LorePinDB → 테스트끼리 상태가 섞이지 않는다.

local support = {}

function support.stub_wow(opts)
    opts = opts or {}
    support.now = opts.now or 1700000000
    time = function() return support.now end
    UnitName = function() return opts.player or "Tester" end
    GetRealmName = function() return opts.realm or "Realm" end
    GetLocale = function() return opts.locale or "enUS" end
    wipe = function(t)
        for k in pairs(t) do t[k] = nil end
        return t
    end
    C_Map = {
        GetBestMapForUnit = function() return opts.mapID end,
        GetPlayerMapPosition = function()
            if not opts.pos then return nil end
            return { GetXY = function() return opts.pos[1], opts.pos[2] end }
        end,
    }
    TomTom = nil
    UiMapPoint = nil
    C_SuperTrack = nil
    UIErrorsFrame = nil
    C_AddOns = nil
    LorePinDB = opts.db
end

-- Core 만 불러온다. UI 파일은 프레임을 만들므로 런타임 밖에서 불러오지 않는다.
function support.addon(opts)
    support.stub_wow(opts)
    local ns = { L = {} }
    load_source("Locale/enUS.lua", ns)
    load_source("Locale/koKR.lua", ns)
    load_source("Core/Config.lua", ns)
    load_source("Core/CategoryManager.lua", ns)
    load_source("Core/PinManager.lua", ns)
    load_source("Core/Notify.lua", ns)
    ns:InitDB()
    ns.printed = {}
    function ns:Print(msg) self.printed[#self.printed + 1] = msg end

    ns.calls = { worldMap = 0, list = 0, removedFromMap = {} }
    function ns:RefreshWorldMapPins() self.calls.worldMap = self.calls.worldMap + 1 end
    function ns:RefreshPinList() self.calls.list = self.calls.list + 1 end
    function ns:RemovePinFromMap(id) self.calls.removedFromMap[#self.calls.removedFromMap + 1] = id end
    return ns
end

function support.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

return support
