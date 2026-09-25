-- THE PALATE: a body that becomes what it eats. Gula's rule, and the Maw of the Unfed's once it is lifted
-- off her (docs/story.md, "The Hunter's Lodge"; the design settled 2026-09-23).
--
-- Every beast in the wood hunts one way. Gula hunts every way, because she has eaten each of them. So a
-- body that can be eaten names ONE thing it gives up -- `palate = "<item id>"` on its blueprint, which
-- is always a piece of that body's own kit (the wyvern's Take Wing, the spider's Silk Shot) -- and the
-- eater takes it into its grid as a live item for the rest of the fight. Nothing here is a new effect:
-- a copied power is the owner's item, already built and already tested on its owner, so the only new
-- balance surface is WHO is holding it.
--
-- ONE APPETITE, on a blueprint that declares `eats = true`: it KEEPS everything. A kind it has not had
-- ADDS its power; a kind it already holds UPGRADES that power a forge level (Item.instantiate at level + 1
-- -- the same scaling the Forge applies, so an upgraded Gore is exactly a forged Gore); a grid with no
-- room left upgrades the weakest power it holds instead. Nothing knocks a power out. (There was a second
-- appetite -- a huntress who held one and lost it to a hard blow -- cut 2026-09-24 when Gula became the
-- beast from the first turn.)
--
-- The held list lives on the unit (`unit.palate`): it is what an upgrade finds its entry in, and what
-- Palate.edibleNear ranks a meal she has not tasted yet against.
--
-- AND THE PLAYER'S HALF IS A MORPH (Palate.morph). Carry the Maw and your killing blow turns the relic
-- ITSELF into the power of what you killed -- the cell shows the fangs, the tooltip reads the fangs --
-- with the relic kept on `morphOf` and put back in the same cell at the bell (Combat.releaseClaims).
--
-- Pure logic, headless-safe; Combat is required lazily, as every model it calls into does.

-- LAZY, both of them. Item blueprints are loaded while models/character.lua is still being required (the
-- registry walks data/items/ mid-load), and ability_devour requires this module -- so a load-time require
-- of Character here is a cycle. The proxies resolve on first use, by which time both are whole; the same
-- trick models/stoop.lua plays for the wyverns.
local function lazy(name)
    return setmetatable({}, { __index = function(_, k) return require(name)[k] end })
end
local Character = lazy("models.character")
local Item = lazy("models.item")

local Palate = {}

-- The power a body gives up, as an item id, or nil for a body that gives nothing (a hawk, a demon, a
-- blueprint nobody has written one for -- which is the safe default: a new beast is inert to the
-- Palate until somebody decides what it tastes of).
--
-- A PARTY BODY has no `palate` on its blueprint, and does not need one: what a company member gives up
-- is the weapon they fight with. That is the "she learns you" half of the fight -- she eats the knight and
-- swings the knight's sword -- and it is read off the grid rather than authored, because the thing she
-- is copying is whatever that knight chose to carry today.
function Palate.powerOf(body)
    local char = body and (body.char or body)
    if not char then return nil end
    local def = Character.defs[char.id]
    local id = def and def.palate
    if id and Item.defs[id] then return id end
    if body.side == "party" then
        local pick = char.defaultAction
        if pick and Item.defs[pick] then return pick end
        for _, item in ipairs(Character.eachItem(char)) do
            if item.type == "weapon" and not item.ephemeral and Item.defs[item.id] then return item.id end
        end
    end
    return nil
end

-- A granted item's own traits, attached to the bearer who is already mid-fight. Trait.attach cannot be
-- re-run for this: it REBUILDS the list, which would reset every counter the fight has been keeping on
-- the others -- a phase cursor, a stack count. So the new piece's traits are appended, and the old
-- piece's are filtered out by the item they came off.
local function attachItemTraits(unit, item)
    local Trait = require("models.trait")
    unit.traits = unit.traits or {}
    for _, id in ipairs(require("models.curse").traitsOn(item)) do
        unit.traits[#unit.traits + 1] = Trait.instantiate(id, item)
    end
end

local function detachItemTraits(unit, item)
    if not (unit.traits and item) then return end
    local keep = {}
    for _, t in ipairs(unit.traits) do
        if t.item ~= item then keep[#keep + 1] = t end
    end
    unit.traits = keep
end

local function nameOf(unit)
    return (unit and unit.char and unit.char.name) or "It"
end

-- Put `id` into `unit`'s grid at `level` as a held power: ephemeral (gone at the bell), unstealable (a
-- pickpocket lifting a borrowed power would lift the only copy of it there is), with its traits live and
-- its passives folded. Returns the item, or nil on a full grid.
local function grant(combat, unit, id, level)
    local Combat = require("models.combat")
    local item = Item.instantiate(id, 1, math.min(level or 0, Item.MAX_LEVEL))
    item.ephemeral = true
    item.noSteal = true
    item.palate = true
    if not Character.addItem(unit.char, item) then return nil end
    attachItemTraits(unit, item)
    Combat.refreshPassives(unit)
    return item
end

local function remove(combat, unit, entry)
    local Combat = require("models.combat")
    if entry.item then
        Character.removeItem(unit.char, entry.item)
        detachItemTraits(unit, entry.item)
    end
    Combat.refreshPassives(unit)
end

-- Raise a held power one forge level: the piece is re-made at the next level in the cell it stood in.
-- A power already at the Forge's ceiling stays where it is.
local function upgrade(combat, unit, entry)
    if (entry.level or 0) >= Item.MAX_LEVEL then return entry end
    local Combat = require("models.combat")
    local slot = entry.item and Character.slotIndex(unit.char, entry.item)
    remove(combat, unit, entry)
    entry.level = (entry.level or 0) + 1
    local item = Item.instantiate(entry.id, 1, entry.level)
    item.ephemeral, item.noSteal, item.palate = true, true, true
    if slot and not unit.char.inventory[slot] then
        unit.char.inventory[slot] = item
    elseif not Character.addItem(unit.char, item) then
        entry.item = nil
        return entry
    end
    entry.item = item
    attachItemTraits(unit, item)
    Combat.refreshPassives(unit)
    Combat.logEvent(combat, "status", string.format("%s's %s grows stronger.",
        nameOf(unit), item.name or entry.id), unit)
    return entry
end

-- `unit` has just eaten `body`: take what it gives up. Returns the held entry that changed, or nil when
-- the body gave nothing. Called from Combat.devour, on the live path only -- the forecast never reaches
-- it, so a hover can never hand Gula a power.
function Palate.take(combat, unit, body)
    local id = Palate.powerOf(body)
    if not (combat and unit and unit.char and id) then return nil end
    -- Only a body whose blueprint EATS takes a power by eating (Gula's). A company member who
    -- swallows a foe with Draw Breath has eaten it and no more -- the player's half of the Palate is the
    -- Maw, which morphs on the kill instead (Palate.morph).
    local def = Character.defs[unit.char.id]
    if not (def and def.eats) then return nil end
    local Combat = require("models.combat")
    unit.palate = unit.palate or {}

    for _, entry in ipairs(unit.palate) do
        if entry.id == id then return upgrade(combat, unit, entry) end
    end

    local item = grant(combat, unit, id, 0)
    if not item then
        -- A full grid: she grows what she has rather than going without.
        local weakest
        for _, entry in ipairs(unit.palate) do
            if not weakest or (entry.level or 0) < (weakest.level or 0) then weakest = entry end
        end
        return weakest and upgrade(combat, unit, weakest) or nil
    end
    local entry = { id = id, level = 0, item = item }
    unit.palate[#unit.palate + 1] = entry
    Combat.logEvent(combat, "status", string.format("%s takes %s for her own.",
        nameOf(unit), item.name or id), unit)
    return entry
end

-- Is `body` something `eater` may devour? The three bodies Combat.devour takes, asked without taking.
function Palate.edible(eater, body)
    if not (eater and body and body.char) or body == eater then return false end
    if body.alive then
        return body.side == eater.side and not body.char.boss and not body.summoned and not body.decoyOf
    end
    if body.devoured then return false end
    if body.incapacitated then return not (body.noRevive and body.laidDown) end
    return body.corpse == true
end

-- Every body `eater` could devour from where it stands: the living of its own side, the downed and the
-- dead, on any tile a step from its footprint (Combat.cellGap, so a 2x2 beast reaches from all four of
-- its cells). Ordered best meal first -- a body whose power it does not yet hold before one it does,
-- the dead before the living (eating your own escort costs a body that is still fighting for you).
function Palate.edibleNear(combat, eater)
    local Combat = require("models.combat")
    if not (combat and eater) then return {} end
    local held = {}
    for _, entry in ipairs(eater.palate or {}) do held[entry.id] = true end
    local out = {}
    for _, u in ipairs(combat.units or {}) do
        if Combat.cellGap(u.x, u.y, eater) == 1 and Palate.edible(eater, u) then
            -- A living body stands on a tile nothing else may, and a fallen one only counts where no
            -- living body is standing on top of it (Combat.corpseAt's rule).
            if u.alive or not Combat.unitAt(combat, u.x, u.y) then out[#out + 1] = u end
        end
    end
    local function rank(u)
        local id = Palate.powerOf(u)
        local r = 0
        if id and not held[id] then r = r - 10 end
        if u.alive then r = r + 5 end
        return r
    end
    table.sort(out, function(a, b)
        local ra, rb = rank(a), rank(b)
        if ra ~= rb then return ra < rb end
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    return out
end

-- THE MAW'S RULE, for whoever carries it: `relic` (the Maw instance) becomes the power `body` gave up.
-- Returns the new item, or nil when nothing changed. A body that gives nothing turns the relic back into
-- itself, which is the blank: kill a hawk and your borrowed fangs are gone.
function Palate.morph(combat, unit, relic, body)
    if not (combat and unit and unit.char and relic) then return nil end
    local Combat = require("models.combat")
    local char = unit.char
    local slot, current
    for i = 1, Character.MAX_INVENTORY do
        local it = char.inventory[i]
        if it and (it == relic or it.morphOf == relic) then slot, current = i, it; break end
    end
    if not slot then return nil end

    local id = Palate.powerOf(body)
    if current ~= relic then detachItemTraits(unit, current) end
    if not id then
        if current == relic then return nil end
        char.inventory[slot] = relic
        Combat.refreshPassives(unit)
        Combat.logEvent(combat, "status", string.format("%s's %s is itself again.",
            nameOf(unit), relic.name or "relic"), unit)
        return relic
    end

    local item = Item.instantiate(id, 1, 0)
    item.ephemeral = true
    item.noSteal = true
    item.morphOf = relic
    char.inventory[slot] = item
    attachItemTraits(unit, item)
    Combat.refreshPassives(unit)
    Combat.logEvent(combat, "status", string.format("%s's %s becomes %s.",
        nameOf(unit), relic.name or "relic", item.name or id), unit)
    return item
end

return Palate
