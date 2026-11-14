describe("fail", function()
    it("eq with key missing in actual", function() eq({ a = 1 }, { a = 1, b = 2 }) end)
end)
