describe("fail", function()
    it("raises with wrong pattern", function() raises(function() error("boom") end, "bang") end)
end)
