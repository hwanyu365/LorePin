local _, ns = ...
local L = ns.L

-- Built-in categories
-- Keys are stable IDs used in pin.category field.
-- Localized names resolved at render time via L.
local function GetBuiltInCategories()
    return {
        {
            id    = "general",
            name  = L.CATEGORY_GENERAL,
            icon  = "Interface\\Icons\\INV_Misc_Note_01",
            color = { r = 1.0, g = 1.0, b = 1.0 },
        },
        {
            id    = "quest",
            name  = L.CATEGORY_QUEST,
            icon  = "Interface\\Icons\\INV_Misc_Map_01",
            color = { r = 1.0, g = 0.82, b = 0.0 },
        },
        {
            id    = "danger",
            name  = L.CATEGORY_DANGER,
            icon  = "Interface\\Icons\\Ability_Creature_Cursed_02",
            color = { r = 1.0, g = 0.2, b = 0.2 },
        },
        {
            id    = "gather",
            name  = L.CATEGORY_GATHER,
            icon  = "Interface\\Icons\\Trade_Herbalism",
            color = { r = 0.2, g = 0.8, b = 0.2 },
        },
        {
            id    = "scenic",
            name  = L.CATEGORY_SCENIC,
            icon  = "Interface\\Icons\\INV_Misc_Spyglass_03",
            color = { r = 0.4, g = 0.6, b = 1.0 },
        },
        {
            id    = "complete",
            name  = L.CATEGORY_COMPLETE,
            icon  = "Interface\\Icons\\Ability_DualWield",
            color = { r = 0.5, g = 0.5, b = 0.5 },
        },
    }
end

-- Returns merged list of built-in + user-defined categories
function ns:GetCategories()
    local list = GetBuiltInCategories()
    for _, custom in ipairs(self.db.customCategories or {}) do
        list[#list + 1] = custom
    end
    return list
end

function ns:GetCategoryById(id)
    for _, cat in ipairs(self:GetCategories()) do
        if cat.id == id then return cat end
    end
    return nil
end

function ns:GetDefaultCategoryId()
    return "general"
end

-- Custom category CRUD
function ns:AddCustomCategory(id, name, icon, color)
    if self:GetCategoryById(id) then
        return false, "category id already exists"
    end
    table.insert(self.db.customCategories, {
        id    = id,
        name  = name,
        icon  = icon  or "Interface\\Icons\\INV_Misc_QuestionMark",
        color = color or { r = 1.0, g = 1.0, b = 1.0 },
        custom = true,
    })
    return true
end

function ns:RemoveCustomCategory(id)
    for i, cat in ipairs(self.db.customCategories) do
        if cat.id == id then
            table.remove(self.db.customCategories, i)
            return true
        end
    end
    return false
end

function ns:IsCustomCategory(id)
    for _, cat in ipairs(self.db.customCategories or {}) do
        if cat.id == id then return true end
    end
    return false
end
