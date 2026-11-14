local support = load_source("scripts/test-support.lua")

local function pin_fields(over)
    local f = { title = "Cave", mapID = 2248, x = 0.5, y = 0.25 }
    for k, v in pairs(over or {}) do f[k] = v end
    return f
end

describe("PinManager", function()
    it("TC#1 제목 nil·빈 문자열·공백뿐이면 생성 거부, 글자가 있으면 생성", function()
        local ns = support.addon()
        local pin, err = ns:CreatePin(pin_fields({ title = "" }))
        eq(pin, nil)
        eq(type(err), "string")
        pin = ns:CreatePin({ mapID = 1, x = 0, y = 0 })
        eq(pin, nil)
        eq(ns:CreatePin(nil), nil)
        for _, blank in ipairs({ " ", "   ", string.char(9), " " .. string.char(10) .. " " }) do
            eq(ns:CreatePin(pin_fields({ title = blank })), nil, "blank title " .. string.format("%q", blank))
            eq(ns:IsBlankTitle(blank), true)
        end
        eq(ns:GetPinCount(), 0)
        eq(ns.calls.worldMap, 0)

        eq(ns:IsBlankTitle(" a "), false)
        local spaced = ns:CreatePin(pin_fields({ title = "  a  " }))
        eq(spaced.title, "  a  ")
    end)

    it("TC#2 핀 수가 maxPins 이면 거부하고 메시지에 한도를 담는다", function()
        local ns = support.addon()
        ns.db.settings.maxPins = 2
        assert(ns:CreatePin(pin_fields()))
        assert(ns:CreatePin(pin_fields()))
        local pin, err = ns:CreatePin(pin_fields())
        eq(pin, nil)
        eq(err, string.format(ns.L.MAX_PINS_REACHED, 2))
        eq(ns:GetPinCount(), 2)
    end)

    it("TC#3 생성 결과 필드·nextPinId 증가·기본값·작성자·갱신 알림", function()
        local ns = support.addon({ now = 1234, player = "Ari", realm = "Azshara" })
        local pin = ns:CreatePin(pin_fields())
        eq(pin, {
            id = 1, title = "Cave", note = "", category = "general",
            mapID = 2248, x = 0.5, y = 0.25,
            createdAt = 1234, updatedAt = 1234, createdBy = "Ari-Azshara",
        })
        eq(ns.db.nextPinId, 2)
        eq(ns.db.pins[1], pin)
        eq(ns.calls.worldMap, 1)
        eq(ns.calls.list, 1)

        local second = ns:CreatePin(pin_fields({ note = "n", category = "danger" }))
        eq(second.id, 2)
        eq(second.note, "n")
        eq(second.category, "danger")
        eq(ns.db.nextPinId, 3)
    end)

    it("TC#4 현재 위치 생성: 지도 없음·위치 없음·(0,0) 이면 거부", function()
        local ns = support.addon({ mapID = nil })
        local pin, err = ns:CreatePinAtPlayer("t")
        eq(pin, nil)
        eq(err, ns.L.NO_MAP)

        ns = support.addon({ mapID = 2248, pos = nil })
        pin, err = ns:CreatePinAtPlayer("t")
        eq(pin, nil)
        eq(err, ns.L.NO_POSITION)

        ns = support.addon({ mapID = 2248, pos = { 0, 0 } })
        pin, err = ns:CreatePinAtPlayer("t")
        eq(pin, nil)
        eq(err, ns.L.NO_POSITION)
        eq(ns:GetPinCount(), 0)
    end)

    it("TC#5 현재 위치 생성 성공: 플레이어 지도·좌표", function()
        local ns = support.addon({ mapID = 2248, pos = { 0.1, 0.2 } })
        local pin = ns:CreatePinAtPlayer("t", "memo", "quest")
        eq({ pin.mapID, pin.x, pin.y, pin.title, pin.note, pin.category }, { 2248, 0.1, 0.2, "t", "memo", "quest" })
    end)

    it("TC#8 부분 수정은 넘긴 필드만 바꾸고 updatedAt 을 갱신, 없는 ID 는 실패", function()
        local ns = support.addon({ now = 100 })
        local pin = ns:CreatePin(pin_fields({ note = "old" }))
        support.now = 200
        local before = ns.calls.worldMap
        eq(ns:UpdatePin(pin.id, { title = "New" }), true)
        eq({ pin.title, pin.note, pin.category, pin.mapID, pin.createdAt, pin.updatedAt },
           { "New", "old", "general", 2248, 100, 200 })
        eq(ns.calls.worldMap, before + 1)

        local ok, err = ns:UpdatePin(99, { title = "x" })
        eq(ok, false)
        eq(err, ns.L.PIN_NOT_FOUND)
        eq(pin.title, "New")
    end)

    it("TC#9 삭제는 핀·지도 표시·TomTom 을 정리하고 갱신, 없는 ID 는 false", function()
        local ns = support.addon()
        local a = ns:CreatePin(pin_fields({ title = "a" }))
        local b = ns:CreatePin(pin_fields({ title = "b" }))
        local removed = {}
        TomTom = {
            AddWaypoint = function() return "uid" end,
            RemoveWaypoint = function(_, uid) removed[#removed + 1] = uid end,
        }
        ns._tomtomUids[a.id] = "uid-a"
        local before = ns.calls.list

        local ok, deleted = ns:DeletePin(a.id)
        eq(ok, true)
        eq(deleted, a)
        eq(ns:GetAllPins(), { b })
        eq(ns.calls.removedFromMap, { a.id })
        eq(removed, { "uid-a" })
        eq(ns._tomtomUids[a.id], nil)
        eq(ns.calls.list, before + 1)

        ok, deleted = ns:DeletePin(a.id)
        eq(ok, false)
        eq(deleted, nil)
        eq(ns:GetPinCount(), 1)
    end)

    it("TC#13 지도별 조회와 검색(대소문자 무시·글자 그대로·빈 검색어 전체)", function()
        local ns = support.addon()
        local a = ns:CreatePin(pin_fields({ title = "Dark Cave", mapID = 1 }))
        local b = ns:CreatePin(pin_fields({ title = "Lake", note = "50% fish (rare)", mapID = 2 }))
        local c = ns:CreatePin(pin_fields({ title = "cavern", mapID = 1 }))
        eq(ns:GetPinsForMap(1), { a, c })
        eq(ns:GetPinsForMap(3), {})
        eq(ns:SearchPins("CAV"), { a, c })
        eq(ns:SearchPins("% fish ("), { b })
        eq(ns:SearchPins("."), {})
        eq(#ns:SearchPins(""), 3)
        eq(#ns:SearchPins(nil), 3)
    end)
end)

describe("길안내", function()
    local function stub_waypoint()
        local state = { wp = nil, tracked = false }
        C_Map.SetUserWaypoint = function(point) state.wp = point end
        C_Map.GetUserWaypoint = function() return state.wp end
        C_Map.ClearUserWaypoint = function() state.wp = nil end
        UiMapPoint = {
            CreateFromCoordinates = function(mapID, x, y) return { uiMapID = mapID, position = { x = x, y = y } } end,
        }
        C_SuperTrack = { SetSuperTrackedUserWaypoint = function(v) state.tracked = v end }
        return state
    end

    it("TC#26 기본 웨이포인트: 활성 판정과 토글, mapID·API 없음이면 nil", function()
        local ns = support.addon()
        local state = stub_waypoint()
        local pin = ns:CreatePin(pin_fields())

        eq(ns:HasActiveWaypoint(pin), false)
        eq(ns:ToggleWaypointForPin(pin), "added")
        eq(state.wp, { uiMapID = 2248, position = { x = 0.5, y = 0.25 } })
        eq(state.tracked, true)
        eq(ns:HasActiveWaypoint(pin), true)

        state.wp = { uiMapID = 2248, position = { x = 0.5009, y = 0.2491 } }
        eq(ns:HasActiveWaypoint(pin), true)
        state.wp = { uiMapID = 2248, position = { x = 0.5011, y = 0.25 } }
        eq(ns:HasActiveWaypoint(pin), false)
        state.wp = { uiMapID = 2248, position = { x = 0.5, y = 0.2511 } }
        eq(ns:HasActiveWaypoint(pin), false)
        state.wp = { uiMapID = 1, position = { x = 0.5, y = 0.25 } }
        eq(ns:HasActiveWaypoint(pin), false)

        state.wp = { uiMapID = 2248, position = { x = 0.5, y = 0.25 } }
        eq(ns:ToggleWaypointForPin(pin), "removed")
        eq(state.wp, nil)

        eq(ns:ToggleWaypointForPin({ id = 9, x = 0, y = 0 }), nil)
        UiMapPoint.CreateFromCoordinates = function() error("api failure") end
        eq(ns:ToggleWaypointForPin(pin), nil)
        C_Map.SetUserWaypoint = nil
        eq(ns:ToggleWaypointForPin(pin), nil)
    end)

    it("TC#27 TomTom: 없으면 nil·메시지, 추가 옵션, 제거, 생성 실패", function()
        local ns = support.addon()
        local pin = ns:CreatePin(pin_fields())

        local result, err = ns:ToggleTomTomForPin(pin)
        eq(result, nil)
        eq(err, ns.L.TOMTOM_NOT_LOADED)
        TomTom = { AddWaypoint = function() return "uid" end }
        result, err = ns:ToggleTomTomForPin(pin)
        eq(result, nil)
        eq(err, ns.L.TOMTOM_NOT_LOADED)

        local added, removed = {}, {}
        TomTom = {
            AddWaypoint = function(_, mapID, x, y, o)
                added[#added + 1] = { mapID, x, y, o }
                return "uid-1"
            end,
            RemoveWaypoint = function(_, uid) removed[#removed + 1] = uid end,
        }
        eq(ns:ToggleTomTomForPin(pin), "added")
        eq(added, { { 2248, 0.5, 0.25, { title = "Cave", minimap = true, world = false, from = "LorePin" } } })
        eq(ns:HasTomTomWaypoint(pin.id), true)

        eq(ns:ToggleTomTomForPin(pin), "removed")
        eq(removed, { "uid-1" })
        eq(ns:HasTomTomWaypoint(pin.id), false)

        TomTom.AddWaypoint = function() error("boom") end
        result, err = ns:ToggleTomTomForPin(pin)
        eq(result, nil)
        eq(type(err), "string")
        eq(ns:HasTomTomWaypoint(pin.id), false)
    end)

    it("TC#28 핀 삭제 시 TomTom 웨이포인트 제거, TomTom 이 없으면 기록만 제거", function()
        local ns = support.addon()
        local pin = ns:CreatePin(pin_fields())
        ns._tomtomUids[pin.id] = "uid-x"
        ns:ClearTomTomForPin(pin.id)
        eq(ns._tomtomUids[pin.id], nil)

        local removed = {}
        TomTom = {
            AddWaypoint = function() return "uid" end,
            RemoveWaypoint = function(_, uid) removed[#removed + 1] = uid end,
        }
        ns._tomtomUids[pin.id] = "uid-y"
        ns:ClearTomTomForPin(pin.id)
        eq(removed, { "uid-y" })
        eq(ns._tomtomUids[pin.id], nil)
    end)
end)
