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

function ns:KnownCategoryOrDefault(id)
    if id ~= nil and self:GetCategoryById(id) then return id end
    return self:GetDefaultCategoryId()
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

local MAX_NAME_CHARS = 24

ns.CUSTOM_CATEGORY_ICONS = {
    [[Interface\Icons\INV_Misc_Bag_10]],
    [[Interface\Icons\INV_Misc_Gem_01]],
    [[Interface\Icons\INV_Misc_Key_03]],
    [[Interface\Icons\INV_Misc_Coin_01]],
    [[Interface\Icons\INV_Misc_Book_09]],
    [[Interface\Icons\INV_Misc_Herb_01]],
    [[Interface\Icons\INV_Ore_Copper_01]],
    [[Interface\Icons\INV_Misc_Fish_02]],
    [[Interface\Icons\INV_Misc_Head_Dragon_01]],
    [[Interface\Icons\INV_Misc_Flower_02]],
    [[Interface\Icons\Ability_Hunter_SniperShot]],
    [[Interface\Icons\INV_Misc_Bone_HumanSkull_01]],
}

local function Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Counts UTF-8 characters, not bytes, so Korean names get the same limit as Latin ones.
local function CharCount(s)
    return select(2, s:gsub("[^\128-\191]", ""))
end

function ns:CheckCategoryName(name)
    if not name or not name:find("%S") then return false, L.CATEGORY_NAME_REQUIRED end
    local trimmed = Trim(name)
    if CharCount(trimmed) > MAX_NAME_CHARS then return false, L.CATEGORY_NAME_TOO_LONG end
    local lowered = trimmed:lower()
    for _, cat in ipairs(self:GetCategories()) do
        if (cat.name or ""):lower() == lowered then return false, L.CATEGORY_NAME_DUPLICATE end
    end
    return true
end

function ns:CreateCustomCategory(name, icon, color)
    local ok, reason = self:CheckCategoryName(name)
    if not ok then return nil, reason end

    local n = 1
    while self:GetCategoryById("custom" .. n) do n = n + 1 end

    local validIcon = self.CUSTOM_CATEGORY_ICONS[1]
    for _, candidate in ipairs(self.CUSTOM_CATEGORY_ICONS) do
        if candidate == icon then validIcon = icon end
    end

    local id = "custom" .. n
    self:AddCustomCategory(id, Trim(name), validIcon, color)
    return self:GetCategoryById(id)
end

-- Returns the number of pins deleted with the category, or nil when it is not a custom category.
function ns:DeleteCustomCategory(id)
    if not self:IsCustomCategory(id) then return nil end
    local doomed = {}
    for _, pin in ipairs(self:GetAllPins()) do
        if pin.category == id then doomed[#doomed + 1] = pin.id end
    end
    self:RemoveCustomCategory(id)
    -- The list panel may be hidden, and a later category can reuse this ID before it shows again.
    if self.ForgetCategoryFilter then self:ForgetCategoryFilter(id) end
    self:DeletePins(doomed)
    if #doomed == 0 then
        if self.RefreshWorldMapPins then self:RefreshWorldMapPins() end
        if self.RefreshPinList      then self:RefreshPinList()      end
    end
    return #doomed
end

function ns:DropUnknownCategories(set)
    for id in pairs(set) do
        if not self:GetCategoryById(id) then set[id] = nil end
    end
    return set
end

function ns:DescribeCategoryFilter(set)
    local count, only = 0, nil
    for id in pairs(set) do
        local cat = self:GetCategoryById(id)
        if cat then
            count = count + 1
            only = cat
        end
    end
    if count == 0 then return L.LIST_FILTER_ALL end
    if count == 1 then return only.name end
    return string.format(L.LIST_FILTER_COUNT, count)
end
