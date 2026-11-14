local support = load_source("scripts/test-support.lua")

describe("Notify", function()
    it("TC#34 실패 알림은 상단 오류 문구(빨간색)와 채팅창에 같은 문구, UIErrorsFrame 이 없어도 채팅창", function()
        local ns = support.addon()
        local shown = {}
        UIErrorsFrame = { AddMessage = function(_, msg, r, g, b) shown[#shown + 1] = { msg, r, g, b } end }
        ns:NotifyError("boom")
        eq(shown, { { "boom", 1.0, 0.1, 0.1 } })
        eq(ns.printed, { "boom" })

        ns = support.addon()
        eq(UIErrorsFrame, nil)
        ns:NotifyError("quiet")
        eq(ns.printed, { "quiet" })
    end)
end)
