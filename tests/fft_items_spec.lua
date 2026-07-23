-- Tests for the Final Fantasy Tactics-derived kit: the Mana Shield (MP Switch), named status immunity
-- (Maintenance), the Guttering Lamp (Sunken State), the Crucible Golem (Golem), the Understudy (Mime)
-- and the Skimmer's Cut (Gilgame Heart).
--
-- Each of the six leans on a seam that did not exist before it, so each is tested at that seam rather
-- than only at "the file loads": damage diverted into the wrong pool, a status refused outright, a
-- reflex that fires on being hit, a guard on a summoned body, an ability that copies another item, and
-- gold accumulating inside a battle that never had a concept of gold. Pure logic, headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

-- A character with an EMPTY grid: blueprints ship starting gear that would otherwise decide these
-- tests for them (a knight carries potions, a rogue carries a dagger). We add exactly what we mean to.
local function bareChar(id)
    local char = Character.instantiate(id)
    for i = 1, Character.MAX_INVENTORY do char.inventory[i] = nil end
    return char
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and bareChar(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function give(char, id, qty)
    local item = Item.instantiate(id, qty)
    Character.addItem(char, item)
    return item
end

return {
    -- ---------------------------------------------------------------- Mana Shield (FFT: MP Switch)
    {
        name = "Mana Shield pays the wound out of mana, and the health pool never moves",
        fn = function()
            local knight = bareChar("character_knight")
            give(knight, "utility_mana_shield")
            local c = Combat.new(arena(8, 8), { unit(knight, 3, 4) }, { unit("character_bandit", 5, 4) })
            local u = c.units[1]
            u.char.stats.mana.current = 20
            local hpBefore = u.char.stats.health.current

            local soaked = Combat.soakIntoMana(c, u, 8)
            assert(soaked == 8, "the whole blow is covered while the pool can afford it, got " .. soaked)
            assert(u.char.stats.mana.current == 12, "a point of mana per point of damage, 1:1")
            assert(u.char.stats.health.current == hpBefore, "and the body is untouched")
        end,
    },
    {
        name = "a dry pool covers nothing, and the blow simply lands",
        fn = function()
            local knight = bareChar("character_knight")
            give(knight, "utility_mana_shield")
            local c = Combat.new(arena(8, 8), { unit(knight, 3, 4) }, { unit("character_bandit", 5, 4) })
            local u = c.units[1]
            u.char.stats.mana.current = 0

            assert(Combat.soakIntoMana(c, u, 8) == 0, "an empty pool wards nothing -- you empty it, you do not beat it")

            -- Partially funded: 3 mana covers 3 points and the remaining 5 reach the body.
            u.char.stats.mana.current = 3
            assert(Combat.soakIntoMana(c, u, 8) == 3, "it covers exactly what the pool can pay for")
            assert(u.char.stats.mana.current == 0, "and spends the pool down to nothing doing it")
        end,
    },
    {
        name = "no shield in the grid diverts nothing at all",
        fn = function()
            local knight = bareChar("character_knight")
            local c = Combat.new(arena(8, 8), { unit(knight, 3, 4) }, { unit("character_bandit", 5, 4) })
            local u = c.units[1]
            u.char.stats.mana.current = 20
            assert(Combat.soakIntoMana(c, u, 8) == 0, "the ward is the item, not the pool")
            assert(u.char.stats.mana.current == 20, "an unwarded caster's mana is not a damage sponge")
        end,
    },
    {
        name = "a wound routed through the damage core spends mana instead of health",
        fn = function()
            local knight = bareChar("character_knight")
            give(knight, "utility_mana_shield")
            local c = Combat.new(arena(8, 8), { unit(knight, 3, 4) }, { unit("character_bandit", 5, 4) })
            local u = c.units[1]
            u.char.stats.mana.current = 40
            local hpBefore = u.char.stats.health.current

            -- A flat source (no attacker): mitigation still applies, then the shield covers the rest.
            local dealt = Combat.dealFlatDamage(c, u, 12, { "physical" }, "a test")
            assert(dealt == 0, "fully covered, so nothing reached the body (got " .. dealt .. ")")
            assert(u.char.stats.health.current == hpBefore, "health is untouched")
            assert(u.char.stats.mana.current < 40, "and the mana pool paid for it")
        end,
    },

    -- ------------------------------------------------------------- Named immunity (FFT: Maintenance)
    {
        name = "a named immunity refuses its status outright, and spares everything else",
        fn = function()
            local alch = bareChar("character_priest")
            give(alch, "utility_tempered_gut") -- immune to Poison and Acid
            local c = Combat.new(arena(8, 8), { unit(alch, 3, 4) }, { unit("character_bandit", 5, 4) })
            local u = c.units[1]

            assert(Status.apply(c, u, "status_poison") == nil, "Poison is refused")
            assert(not Status.has(u, "status_poison"), "and nothing is left on the unit")
            assert(Status.apply(c, u, "status_acid") == nil, "Acid too -- both are named")

            -- Not a blanket ward: a status it does not name still lands.
            assert(Status.apply(c, u, "status_burn") ~= nil, "Burn is not named, so Burn lands")
            assert(Status.has(u, "status_burn"), "the immunity is a list, not a shrug")
        end,
    },
    {
        name = "an immunity never blocks a buff, however it is named",
        fn = function()
            local alch = bareChar("character_priest")
            -- A hand-built item naming a BUFF: the guard is that `debuff` gates the whole mechanism,
            -- so no authored immunity can ever refuse something the bearer wanted.
            local charm = Item.instantiate("utility_tempered_gut")
            charm.statusImmunity = { "status_regen" }
            Character.addItem(alch, charm)
            local c = Combat.new(arena(8, 8), { unit(alch, 3, 4) }, { unit("character_bandit", 5, 4) })
            local u = c.units[1]

            assert(Status.apply(c, u, "status_regen") ~= nil, "a buff is never refused")
            assert(Status.has(u, "status_regen"), "no item may tell you that you cannot be helped")
        end,
    },
    {
        name = "without the charm the same status lands normally",
        fn = function()
            local alch = bareChar("character_priest")
            local c = Combat.new(arena(8, 8), { unit(alch, 3, 4) }, { unit("character_bandit", 5, 4) })
            assert(Status.apply(c, c.units[1], "status_poison") ~= nil, "the charm is doing the work, not the class")
        end,
    },

    -- ------------------------------------------------------------ Guttering Lamp (FFT: Sunken State)
    {
        name = "the Guttering Lamp hides its bearer the moment it is struck",
        fn = function()
            local rogue = bareChar("character_archer")
            give(rogue, "utility_vanishing_act")
            local c = Combat.new(arena(8, 8), { unit(rogue, 3, 4) }, { unit("character_bandit", 5, 4) })
            local u = c.units[1]
            assert(Trait.has(u, "trait_vanishing_act"), "the item granted its trait")
            assert(not Status.has(u, "status_invisible"), "and it has not fired yet")

            Combat.dealFlatDamage(c, u, 6, { "physical" }, "a test")
            assert(u.alive, "the blow was survivable")
            assert(Status.has(u, "status_invisible"), "struck and still standing, the bearer slips out of sight")
        end,
    },
    {
        name = "a rogue without the lamp stays visible when hit",
        fn = function()
            local rogue = bareChar("character_archer")
            local c = Combat.new(arena(8, 8), { unit(rogue, 3, 4) }, { unit("character_bandit", 5, 4) })
            Combat.dealFlatDamage(c, c.units[1], 6, { "physical" }, "a test")
            assert(not Status.has(c.units[1], "status_invisible"), "the reflex is the item's, not the class's")
        end,
    },

    -- --------------------------------------------------------------- Crucible Golem (FFT: Golem)
    {
        name = "the Crucible Golem stands in front of the ally beside it",
        fn = function()
            -- NOT bareChar here: the golem's guard rides on its hands
            -- (data/items/weapon/weapon_golem_fists.lua), because a blueprint's own `traits` field
            -- never reaches the runtime character. Emptying its grid would strip the very thing
            -- under test -- which is the whole point worth pinning.
            local golem = { char = Character.instantiate("character_crucible_golem"), x = 3, y = 4 }
            local c = Combat.new(arena(8, 8),
                { golem, unit("character_mage", 4, 4) },
                { unit("character_bandit", 6, 4) })
            local mage
            golem, mage = c.units[1], c.units[2]
            assert(Trait.has(golem, "trait_bulwark"), "the guard reached the unit from its hands")
            assert(golem.guard, "Bulwark set the guard at the opening bell")

            local taker = Combat.tryRedirect(c, mage, 10, { "physical" })
            assert(taker == golem, "the blow aimed at the mage is taken by the golem instead")
        end,
    },
    {
        name = "the golem is a wall, not a fist: more health and armor than the Homunculus, less damage",
        fn = function()
            local golem = Character.instantiate("character_crucible_golem")
            local homunculus = Character.instantiate("character_homunculus")
            assert(golem.stats.health.max > homunculus.stats.health.max, "it is the heavier body")
            assert(golem.stats.defense > homunculus.stats.defense, "and the better armored one")
            assert(golem.stats.damage < homunculus.stats.damage,
                "and it hits for less -- summoning it to kill things is a misread of the item")
        end,
    },

    -- ------------------------------------------------------------------- Understudy (FFT: Mime)
    {
        name = "the Understudy repeats an ally's physical motion, and names it in its own label",
        fn = function()
            local fighter = bareChar("character_champion")
            local sword = give(fighter, "weapon_iron_sword")
            local alch = bareChar("character_priest")
            local mimic = give(alch, "ability_understudy")

            local c = Combat.new(arena(8, 8),
                { unit(fighter, 3, 4), unit(alch, 3, 5) },
                { unit("character_bandit", 4, 4), unit("character_bandit", 4, 5) })
            local hero, copier, foeA, foeB = c.units[1], c.units[2], c.units[3], c.units[4]

            -- Nothing rehearsed: the ability is greyed and says so, and the label is the idle one.
            local ok, why = mimic.activeAbility.usable(copier, mimic)
            assert(not ok and why == "nothing rehearsed yet", "an understudy with nothing to copy cannot act")
            assert(mimic.name == "Understudy", "and its label makes no promises")

            -- The fighter swings. That is the motion the whole side has now watched.
            assert(Combat.useItem(c, hero, sword, foeA.x, foeA.y), "the sword swing resolved")
            assert(copier.lastPhysical == sword, "the swing was recorded for the copier's side")

            assert(mimic.activeAbility.usable(copier, mimic), "now there is something to repeat")
            assert(mimic.name == "Understudy: Iron Sword",
                "and the tooltip names what is actually in hand, got: " .. tostring(mimic.name))

            local before = foeB.char.stats.health.current
            assert(Combat.useItem(c, copier, mimic, foeB.x, foeB.y), "the copy resolved")
            assert(foeB.char.stats.health.current < before, "and it hit, with the borrowed sword")
        end,
    },
    {
        name = "the Understudy copies muscle, never magic -- that is Pride's, not Envy's",
        fn = function()
            local mage = bareChar("character_mage")
            local bolt = give(mage, "ability_fire_bolt") -- a mana cast: sorcery by Combat.isMagicItem
            local alch = bareChar("character_priest")
            local mimic = give(alch, "ability_understudy")

            local c = Combat.new(arena(8, 8),
                { unit(mage, 3, 4), unit(alch, 3, 5) },
                { unit("character_bandit", 5, 4) })
            local caster, copier, foe = c.units[1], c.units[2], c.units[3]
            caster.char.stats.mana.current = caster.char.stats.mana.max

            assert(Combat.useItem(c, caster, bolt, foe.x, foe.y), "the bolt resolved")
            assert(copier.lastPhysical == nil, "a spell leaves nothing to imitate")
            local ok = mimic.activeAbility.usable(copier, mimic)
            assert(not ok, "so the Understudy is still empty-handed after watching a mage work")
        end,
    },
    {
        name = "an enemy's swing is never what the party's Understudy repeats",
        fn = function()
            local alch = bareChar("character_priest")
            local mimic = give(alch, "ability_understudy")
            local raider = bareChar("character_bandit")
            local axe = give(raider, "weapon_iron_axe")

            local c = Combat.new(arena(8, 8), { unit(alch, 3, 4) }, { unit(raider, 4, 4) })
            local copier, foe = c.units[1], c.units[2]

            assert(Combat.useItem(c, foe, axe, copier.x, copier.y), "the raider swung")
            assert(copier.lastPhysical == nil,
                "the record is per side: you rehearse your own, never the thing that just hit you")
        end,
    },

    -- ------------------------------------------------------- Skimmer's Cut (FFT: Gilgame Heart)
    {
        name = "the Skimmer's Cut banks coin on a landed blow, and the battle carries it",
        fn = function()
            local rogue = bareChar("character_archer")
            give(rogue, "utility_skimmers_cut")
            local dagger = give(rogue, "weapon_iron_dagger")

            local c = Combat.new(arena(8, 8), { unit(rogue, 3, 4) }, { unit("character_bandit", 4, 4) })
            local thief, foe = c.units[1], c.units[2]
            assert((c.skimmed or 0) == 0, "nothing taken before the first swing")

            assert(Combat.useItem(c, thief, dagger, foe.x, foe.y), "the cut landed")
            assert((c.skimmed or 0) > 0, "and something came off the enemy with it")
        end,
    },
    {
        name = "an enemy wearing the same charm skims nothing -- there is no purse on that side",
        fn = function()
            local raider = bareChar("character_bandit")
            give(raider, "utility_skimmers_cut")
            local dagger = give(raider, "weapon_iron_dagger")

            local c = Combat.new(arena(8, 8), { unit("character_archer", 3, 4) }, { unit(raider, 4, 4) })
            local hero, foe = c.units[1], c.units[2]

            assert(Combat.useItem(c, foe, dagger, hero.x, hero.y), "the raider's cut landed")
            assert((c.skimmed or 0) == 0, "the charm is worth what it is worth to YOU, and nothing to them")
        end,
    },
    {
        name = "Combat.skimGold refuses a non-party skimmer and an empty take",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_archer", 3, 4) }, { unit("character_bandit", 4, 4) })
            assert(Combat.skimGold(c, c.units[2], 5) == 0, "an enemy banks nothing")
            assert(Combat.skimGold(c, c.units[1], 0) == 0, "and a zero take is not a take")
            assert((c.skimmed or 0) == 0, "neither one moved the total")
        end,
    },
}
