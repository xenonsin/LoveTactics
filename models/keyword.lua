-- Keywords: the declarative fields an `activeAbility` (or a neighbour's `aura`) opts into, and the
-- one-line definition of each. The mechanics themselves live in models/combat.lua -- this module owns
-- only the WORDS, so a tooltip can explain a keyword it finds without the UI carrying prose about
-- rules it does not implement. The contract the fields belong to is docs/weapons.md.
--
-- A keyword's blueprint is data/keywords/<id>.lua = { name, description }, loaded like every other
-- data folder. The maps below are the whole coupling between a field name and its entry.
--
-- Pure logic (no love.graphics), so it loads under the headless tests.

local Registry = require("models.registry")

local Keyword = {}

Keyword.defs = Registry.load("data/keywords", "data.keywords")

-- activeAbility field -> keyword id, in the order a tooltip should read them out: what the cast COVERS,
-- then what it does with what it caught, then the conditions on aiming it, then the wind-up rules.
--
-- Four documented keywords are deliberately absent -- `channel`, `consumesItem`, `requiresAdjacent`
-- and `reserve`. The item tooltip already spells each out in prose beside its own stat row, and a
-- glossary that repeated them would say the same thing twice on the same hover.
local ABILITY_FIELDS = {
    { field = "aoe", id = "keyword_aoe" },
    { field = "frenzy", id = "keyword_frenzy" },
    { field = "lifesteal", id = "keyword_lifesteal" },
    { field = "requiresSight", id = "keyword_requires_sight" },
    { field = "minRange", id = "keyword_min_range" },
    { field = "windup", id = "keyword_windup" },
    { field = "steadfast", id = "keyword_steadfast" },
}

-- `aura` field -> keyword id: the three that change what a neighbouring cast IS, rather than what it
-- is worth. A pure number (amountBonus, rangeBonus, speedBonus) needs no definition -- it reads off
-- the item's own description -- so only these carry glossary entries.
local AURA_FIELDS = {
    { field = "careful", id = "keyword_careful" },
    { field = "twin", id = "keyword_twin" },
    { field = "preserve", id = "keyword_preserve" },
}

-- `waitBehavior` field -> keyword id. Only one so far: a stance that changes what the BOARD costs
-- rather than what the stance itself does needs explaining, because nothing about the word "Overwatch"
-- suggests it. The other wait fields (speed, stamina, power, status) are numbers or effects the
-- tooltip already prints in full beside the stance's own row.
local WAIT_FIELDS = {
    { field = "zone", id = "keyword_watched_ground" },
}

-- Is `value` a real declaration of `field`, or the inert shape of one? A keyword is usually a flag or a
-- table and simply being present says it, but the numeric ones have a threshold below which the field
-- is declared and means nothing: `minRange = 1` is every melee weapon in the game and no dead zone at
-- all (the same test ui/item_tooltip.lua uses to decide whether to print a range BAND), and a zero
-- frenzy/lifesteal share adds nothing to a swing.
local function declared(field, value)
    if value == nil or value == false then return false end
    if field == "minRange" then return value > 1 end
    if field == "frenzy" or field == "lifesteal" or field == "zone" then return value > 0 end
    return true
end

-- The keyword ids `item` declares: ability keywords first, then aura, then the wait stance. Empty for
-- an item that declares none, which is most of them.
function Keyword.forItem(item)
    local ids = {}
    if not item then return ids end
    local ab = item.activeAbility
    if ab then
        for _, entry in ipairs(ABILITY_FIELDS) do
            if declared(entry.field, ab[entry.field]) then ids[#ids + 1] = entry.id end
        end
    end
    if item.aura then
        for _, entry in ipairs(AURA_FIELDS) do
            if declared(entry.field, item.aura[entry.field]) then ids[#ids + 1] = entry.id end
        end
    end
    if item.waitBehavior then
        for _, entry in ipairs(WAIT_FIELDS) do
            if declared(entry.field, item.waitBehavior[entry.field]) then ids[#ids + 1] = entry.id end
        end
    end
    return ids
end

return Keyword
