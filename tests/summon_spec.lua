-- Tests for summoning (models/summon.lua + models/combat.lua): a character placed on the field
-- mid-battle joins the turn order, obeys whoever called it, and is sustained by the resource its
-- summoner reserved. Kill either end of that bond and the other is freed. Pure logic, runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Summon = require("models.summon")

local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

local function itemNamed(char, id)
    for i = 1, Character.MAX_INVENTORY do
        local it = char.inventory[i]
        if it and it.id == id then return it end
    end
    return nil
end

-- Wipe a character's grid and place `ids` from slot 1, so a spec controls the whole loadout.
local function equip(char, ids)
    char.inventory = {}
    for _, id in ipairs(ids) do Character.addItem(char, Item.instantiate(id)) end
end

local function inOrder(c, u)
    for _, entry in ipairs(Combat.turnOrder(c)) do
        if entry == u then return true end
    end
    return false
end

return {
    {
        name = "a summon joins the units, the turn order, and starts at its own natural initiative",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("archer", 1, 1) }, { unit("bandit", 8, 8) })
            local archer = c.units[1]
            local before = #c.units

            local wolf = Summon.spawn(c, archer, "wolf_grunt", 2, 1)
            assert(#c.units == before + 1, "it is a real unit on the field")
            assert(Combat.unitAt(c, 2, 1) == wolf, "standing where it was called")
            assert(inOrder(c, wolf), "and it takes turns")

            local natural = math.max(0, Combat.initiative(wolf.char))
            assert(wolf.initiative == natural,
                "it enters at its own initiative, clamped so it can't cut ahead of the acting unit")
            assert(archer.initiative == 0, "the summoner keeps the turn it is in the middle of")
        end,
    },
    {
        name = "a summon inherits its summoner's controller, and its passives are folded in",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("archer", 1, 1) }, { unit("bandit", 8, 8) })
            local archer, bandit = c.units[1], c.units[2]

            local mine = Summon.spawn(c, archer, "wolf_grunt", 2, 1)
            assert(mine.side == "party" and Combat.isPlayerControlled(mine), "my wolf answers to me")
            assert(mine.bonus and mine.resist, "its item passives were folded in on arrival")

            local theirs = Summon.spawn(c, bandit, "wolf_grunt", 7, 8)
            assert(theirs.side == "enemy" and theirs.control == "ai", "their wolf answers to the AI")

            local inert = Summon.spawn(c, archer, "wolf_grunt", 1, 2, { control = "none" })
            assert(not Combat.isPlayerControlled(inert), "an inert summon is nobody's to command")
        end,
    },
    {
        name = "power scales a summon additively, per stat, and it arrives at full health",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("archer", 1, 1) }, { unit("bandit", 8, 8) })
            local archer = c.units[1]
            local base = Character.defs.wolf_grunt.stats

            local wolf = Summon.spawn(c, archer, "wolf_grunt", 2, 1, {
                scaling = { health = 2, damage = 0.5 }, power = 10,
            })
            local hp = wolf.char.stats.health
            assert(hp.max == base.health + 20, "health max grew by power * factor")
            assert(hp.current == hp.max, "and it arrives unwounded, not at its old current")
            assert(wolf.char.stats.damage == base.damage + 5, "damage grew by power * factor")
        end,
    },
    {
        name = "an ability's reservation is bound to the creature it summons",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 2, 2) }, { unit("bandit", 8, 8) })
            local mage = c.units[1]
            openTurn(c, mage)
            local mana = mage.char.stats.mana
            local expected = math.floor(mana.max * 0.25)

            local summon = itemNamed(mage.char, "ability_summon_fire_elemental")
            assert(Combat.useItem(c, mage, summon, 3, 2), "the cast lands on the empty tile")

            local elemental = Combat.unitAt(c, 3, 2)
            assert(elemental and elemental.char.id == "fire_elemental", "the elemental is there")
            assert(Combat.reservedAmount(mage.char, "mana") == expected, "a quarter of max mana is committed")
            assert(mana.max == 80, "the maximum itself is untouched")
            assert(Combat.unreservedMax(mage.char, "mana") == 80 - expected, "only the ceiling moved")
        end,
    },
    {
        name = "killing a summon releases the mana its summoner set aside",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 2, 2) }, { unit("bandit", 8, 8) })
            local mage = c.units[1]
            openTurn(c, mage)
            local summon = itemNamed(mage.char, "ability_summon_fire_elemental")
            Combat.useItem(c, mage, summon, 3, 2)
            local elemental = Combat.unitAt(c, 3, 2)
            assert(Combat.reservedAmount(mage.char, "mana") > 0, "committed while it lives")

            Combat.dealFlatDamage(c, elemental, 9999, { "physical" })
            assert(not elemental.alive, "the elemental falls")
            assert(Combat.reservedAmount(mage.char, "mana") == 0, "and the mage's mana is freed")
            assert(Combat.unreservedMax(mage.char, "mana") == 80, "the ceiling is whole again")
        end,
    },
    {
        name = "killing the summoner dismisses its summons and frees the reservation",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 2, 2) }, { unit("bandit", 8, 8) })
            local mage = c.units[1]
            openTurn(c, mage)
            Combat.useItem(c, mage, itemNamed(mage.char, "ability_summon_fire_elemental"), 3, 2)
            local elemental = Combat.unitAt(c, 3, 2)

            Combat.dealFlatDamage(c, mage, 9999, { "physical" })
            assert(not mage.alive, "the mage falls")
            assert(not elemental.alive, "and what it was sustaining vanishes with it")
            assert(Combat.reservedAmount(mage.char, "mana") == 0, "no reservation outlives its holder")
        end,
    },
    {
        name = "a live enemy summon blocks killAll; killing its summoner dismisses it and resolves the fight",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit", 8, 8) })
            local bandit = c.units[2]
            local wolf = Summon.spawn(c, bandit, "wolf_grunt", 7, 8)

            -- Kill the bandit's summoner-less companion first: only the wolf is left standing, and it
            -- is an enemy like any other, so the objective must not resolve.
            Combat.dealFlatDamage(c, bandit, 9999, { "physical" })
            -- ...except the wolf was sustained by the bandit, so it went with it.
            assert(not wolf.alive, "its summon is dismissed with it")
            assert(Combat.aliveCount(c, "enemy") == 0, "nothing hostile is left")
            assert(Combat.evaluate(c) == "win", "so killAll resolves without hunting the summon down")
        end,
    },
    {
        name = "a summon of a still-living enemy keeps killAll open",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit", 8, 8) })
            local bandit = c.units[2]
            -- Give the wolf an independent summoner that never dies, so it outlives the bandit.
            local wolf = Summon.spawn(c, bandit, "wolf_grunt", 7, 8)
            wolf.summoner = nil

            Combat.dealFlatDamage(c, bandit, 9999, { "physical" })
            assert(wolf.alive, "nothing sustains it, so it stays")
            assert(Combat.evaluate(c) == nil, "and it must be killed like any other enemy")

            Combat.dealFlatDamage(c, wolf, 9999, { "physical" })
            assert(Combat.evaluate(c) == "win", "once it falls, the field is clear")
        end,
    },
    {
        name = "a summoned duplicate of an assassination target does not count as the target",
        fn = function()
            local c = Combat.new(arena(8, 8, { type = "assassinate", target = "bandit_chief" }),
                { unit("knight", 1, 1) }, { unit("bandit_chief", 8, 8) })
            local chief = c.units[2]

            local double = Summon.copy(c, chief, 7, 8, { fragile = true })
            assert(double.char.id == "bandit_chief", "the copy shares the mark's identity")
            assert(double.summoned, "but it is flagged as conjured")

            Combat.dealFlatDamage(c, chief, 9999, { "physical" })
            assert(not double.alive, "the double is dismissed with its summoner")
            assert(Combat.evaluate(c) == "win", "killing the real mark ends the hunt")
        end,
    },
    {
        name = "a copy carries the caster's current stats and kit, minus anything marked noCopy",
        fn = function()
            local mage = Character.instantiate("mage")
            equip(mage, { "ability_fireball", "ability_doppelganger", "silk_robes" })
            local c = Combat.new(arena(8, 8), { unit(mage, 2, 2) }, { unit("bandit", 8, 8) })
            local caster = c.units[1]
            caster.char.stats.health.current = 31 -- wounded

            local double = Summon.copy(c, caster, 3, 2, { fragile = true })
            assert(double.char.stats.health.current == 31, "the copy is as wounded as the original")
            assert(itemNamed(double.char, "ability_fireball"), "it carries the caster's spells")
            assert(itemNamed(double.char, "silk_robes"), "and its armor")
            assert(not itemNamed(double.char, "ability_doppelganger"),
                "but never the ability that made it -- a copy cannot copy itself")
            assert(double.char.inventory ~= caster.char.inventory, "the grids are separate")
        end,
    },
    {
        name = "a fragile summon dies to any hit at all",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 2, 2) }, { unit("bandit", 8, 8) })
            local knight = c.units[1]
            local double = Summon.copy(c, knight, 3, 2, { fragile = true })
            assert(double.char.stats.health.current > 1, "it looks perfectly healthy")

            Combat.dealFlatDamage(c, double, 1, { "physical" })
            assert(not double.alive, "one scratch and the illusion collapses")
        end,
    },
    {
        name = "a summon ability is refused when its reservation cannot be committed",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 2, 2) }, { unit("bandit", 8, 8) })
            local mage = c.units[1]
            openTurn(c, mage)
            mage.char.stats.mana.current = 1

            local ok, reason = Combat.useItem(c, mage, itemNamed(mage.char, "ability_summon_fire_elemental"), 3, 2)
            assert(not ok and reason == "insufficient mana", "you cannot set aside what you don't hold")
            assert(Combat.unitAt(c, 3, 2) == nil, "and nothing was summoned")
            assert(c.turn ~= nil, "the turn was never spent")
        end,
    },
    {
        name = "the summon tooltip preview names the creature without spawning it",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("archer", 2, 2) }, { unit("bandit", 8, 8) })
            local archer = c.units[1]
            local before = #c.units

            local out = Combat.abilityOutput(archer, itemNamed(archer.char, "ability_summon_wolf"))
            assert(out and out.summon == "wolf_grunt", "the dry run reports what would be summoned")
            assert(#c.units == before, "and summons nothing")

            local preview = Combat.previewAbility(c, archer, itemNamed(archer.char, "ability_summon_wolf"), 3, 2)
            assert(preview ~= nil, "the aimed preview resolves")
            assert(#c.units == before, "still nothing summoned")
        end,
    },
}
