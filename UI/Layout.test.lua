local support = load_source("scripts/test-support.lua")

local function fake_frame()
    local f = { scripts = {}, propagateCalls = {}, hidden = 0 }
    function f:EnableKeyboard(on) self.keyboard = on end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:SetPropagateKeyboardInput(on) self.propagateCalls[#self.propagateCalls + 1] = on end
    function f:Hide() self.hidden = self.hidden + 1 end
    return f
end

local function layout()
    local ns = support.addon()
    load_source("UI/Layout.lua", ns)
    return ns.Layout
end

describe("ESC 닫기", function()
    it("TC#37 ESC 는 가로채고 닫기 동작을 부르며, 다른 키는 게임으로 넘긴다", function()
        local Layout = layout()
        local f = fake_frame()
        local closed = {}
        Layout.CloseOnEscape(f, function(self) closed[#closed + 1] = self end)
        eq(f.keyboard, true)

        f.scripts.OnKeyDown(f, "W")
        eq(f.propagateCalls, { true })
        eq(#closed, 0)

        f.scripts.OnKeyDown(f, "ESCAPE")
        eq(f.propagateCalls, { true, false })
        eq(closed, { f })

        f.scripts.OnKeyUp(f, "ESCAPE")
        eq(f.propagateCalls, { true, false, true })
        eq(f.hidden, 0)
    end)

    it("TC#37 닫기 동작이 없으면 창을 숨긴다", function()
        local Layout = layout()
        local f = fake_frame()
        Layout.CloseOnEscape(f)
        f.scripts.OnKeyDown(f, "ESCAPE")
        eq(f.hidden, 1)
    end)

    it("TC#37 그 창의 확인 대화상자가 떠 있으면 ESC 는 확인 대화상자만 닫는다", function()
        local Layout = layout()
        local visible = { LOREPIN_B = true }
        local hiddenPopups = {}
        StaticPopup_Visible = function(name) return visible[name] and "StaticPopup1" or nil end
        StaticPopup_Hide = function(name) hiddenPopups[#hiddenPopups + 1] = name; visible[name] = nil end
        local f = fake_frame()
        local closed = 0
        Layout.CloseOnEscape(f, function() closed = closed + 1 end, { "LOREPIN_A", "LOREPIN_B" })

        f.scripts.OnKeyDown(f, "ESCAPE")
        eq(hiddenPopups, { "LOREPIN_B" })
        eq(closed, 0)
        eq(f.propagateCalls, { false })

        f.scripts.OnKeyDown(f, "ESCAPE")
        eq(closed, 1)
    end)

    it("TC#37 전투 중에는 키 전달을 바꾸지 않고 닫기만 한다", function()
        local Layout = layout()
        InCombatLockdown = function() return true end
        local f = fake_frame()
        local closed = 0
        Layout.CloseOnEscape(f, function() closed = closed + 1 end)
        f.scripts.OnKeyDown(f, "ESCAPE")
        f.scripts.OnKeyDown(f, "W")
        f.scripts.OnKeyUp(f, "ESCAPE")
        eq(f.propagateCalls, {})
        eq(closed, 1)
    end)
end)
