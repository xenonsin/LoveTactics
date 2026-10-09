-- Tests for THE CROWN'S BESTIARY, SLICE E (2026-10-09, "The Crown's Bestiary"): the Lethe-Drinker, the Hungry Ghost
-- and the Lernaean Hydra, their rules, their pieces and their one fight.
--
--   Lethe Haze    a foe within 2 of the Drinker cannot use the same ability two turns running (models/lethe.lua)
--   Never Full    a heal or draught landing within 2 of a Hungry Ghost is eaten: the ghost is healed instead
--   Two for One   the Hydra opens with three heads, one bite each; a slash of a tenth of its bar takes a head and
--                 two grow back (up to 6); Fire or Burn cauterises for 2 turns (models/lerna.lua)
--   the pieces    the Cup of Lethe, the Pinhole Mouth, and all three of the Hydra's: Two Heads, Cauterise (which
--                 also stops an Archon's wisp raising its body) and Hydra's Blood
--   the fight     The Grey Shore. The Hydra is FIELDED BY "LERNA" (the Hydra and a Chain Fiend), which the
--                 coordinator builds after the merge; nothing in this slice seats it, and that is expected.
-- Each rule is pinned on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Lethe = require("models.lethe")
local Lerna = require("models.lerna")
local Spirit = require("models.spirit")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local BODIES = { "character_lethe_drinker", "character_hungry_ghost", "character_lernaean_hydra" }
local TROPHIES = {
    utility_cup_of_lethe = { "character_lethe_drinker", "warden", "utility",
        "Foes within 2 of you can't use the same ability two turns running." },
    utility_pinhole_mouth = { "character_hungry_ghost", "spellbreaker", "utility",
        "Heals that land on foes within 2 of you heal you instead." },
    armor_two_heads = { "character_lernaean_hydra", "barbarian", "armor",
        "Each time a slash blow strikes you, your next attack strikes one more time (up to 3)." },
    ability_cauterise = { "character_lernaean_hydra", "crusader", "ability",
        "Burn a foe: for 2 turns it can't be healed, regenerate, or stand back up." },
    utility_hydras_blood = { "character_lernaean_hydra", "poisoner", "utility",
        "Your blows Poison. When a Poisoned foe falls, its Poison spreads to every foe beside it." },
}
local ORGANS = { "utility_lethe_haze", "utility_never_full", "utility_two_for_one", "weapon_hungry_grasp",
    "weapon_hydra_jaws" }

local function board(n) return Fixture.new(n or 11, n or 11) end

local function body(id, x, y, health)
    return unit(id, x, y, { stats = { health = health or 200 } })
end

-- A bare party body carrying exactly `items`.
local function hand(x, y, items, health)
    return unit("character_archer", x, y, { isolate = "bare", items = items or {},
        stats = { health = health or 300, mana = 100, stamina = 100 } })
end

local function find(c, pred) for _, u in ipairs(c.units) do if pred(u) then return u end end end
local function at(c, x, y) return find(c, function(u) return u.x == x and u.y == y end) end
local function idOf(c, id) return find(c, function(u) return u.char and u.char.id == id end) end
local function maxHp(u) return Combat.unreservedMax(u.char, "health") end
local function wound(c, u, n) Combat.dealFlatDamage(c, u, n, { "physical" }, "test", nil, { raw = true }) end

return {
    -- ------------------------------------------------------------------------------ the content
    { name = "the three bodies: two dead things and a beast, each with its organ, never human", fn = function()
        local drinker = Character.defs.character_lethe_drinker
        local ghost = Character.defs.character_hungry_ghost
        local hydra = Character.defs.character_lernaean_hydra
        assert(drinker.race == "undead" and drinker.tier == 2, "the Lethe-Drinker is a tier-2 dead thing")
        assert(ghost.race == "undead" and ghost.tier == 2, "the Hungry Ghost is a tier-2 dead thing")
        assert(hydra.race == "beast" and hydra.tier == 4 and hydra.boss, "the Hydra is a tier-4 beast elite")
        assert(hydra.footprint.w == 2 and hydra.footprint.h == 2, "the Hydra stands 2x2")
        assert(drinker.unarmed == false and not drinker.defaultAction, "the Drinker does nothing to you directly")
        local c = Character.instantiate("character_lethe_drinker")
        assert(itemNamed(c, "utility_lethe_haze"), "it carries the river")
        for _, it in ipairs(Character.eachItem(c)) do
            assert(it.type ~= "weapon", "and nothing to strike with: " .. it.id)
        end
        assert(itemNamed(Character.instantiate("character_hungry_ghost"), "utility_never_full"), "the ghost is Never Full")
        assert(itemNamed(Character.instantiate("character_lernaean_hydra"), "utility_two_for_one"), "the Hydra is Two for One")
        for _, id in ipairs(BODIES) do assert(Character.defs[id].race ~= "human", id .. " is not human") end
        for _, id in ipairs(ORGANS) do
            local def = Item.defs[id]
            assert(def and def.class == "creature" and def.noSteal, id .. " is a body's own")
            if def.type == "utility" then assert(def.bound, id .. " is an organ") end
        end
    end },

    { name = "every trophy is an unstocked find on its body's drop list, on the approved shelf, word for word", fn = function()
        for id, want in pairs(TROPHIES) do
            local def = Item.defs[id]
            assert(def, id .. " exists")
            assert(def.unstocked, id .. " is a trophy: seen on the rack, never sold")
            assert(def.class == want[2], id .. " sits on the " .. want[2] .. " shelf")
            assert(def.type == want[3], id .. " is a " .. want[3])
            assert(def.description == want[4], id .. " reads as approved")
            local listed = false
            for _, d in ipairs(Character.defs[want[1]].drops or {}) do if d == id then listed = true end end
            assert(listed, id .. " is on " .. want[1] .. "'s drop list")
        end
        local drops = Character.defs.character_lernaean_hydra.drops
        assert(#drops == 3, "all three of the Hydra's pieces ship off its own list")
    end },

    -- ------------------------------------------------------------------------------ Lethe Haze
    { name = "Lethe Haze: within 2, last turn's ability is refused; another one, or the fists, are not", fn = function()
        local c = Fixture.combat(board(), hand(5, 7, { "weapon_iron_sword", "weapon_iron_dagger" }),
            { body("character_lethe_drinker", 5, 5), body("character_hungry_ghost", 5, 8) })
        local me, ghost = at(c, 5, 7), idOf(c, "character_hungry_ghost")
        local sword, dagger = itemNamed(me.char, "weapon_iron_sword"), itemNamed(me.char, "weapon_iron_dagger")
        openTurn(c, me)
        assert(Combat.useItem(c, me, sword, ghost.x, ghost.y), "the sword swings")
        assert(not Combat.itemBlockReason(me, sword), "the same turn is not two turns")
        -- The next turn opens through Combat.startTurn, which is what rolls the memory over.
        for _, u in ipairs(c.units) do u.initiative = 50 end
        me.initiative = 0
        Combat.startTurn(c)
        assert(Combat.currentUnit(c) == me, "it is my turn again")
        local block = Combat.itemBlockReason(me, sword)
        assert(block and block.kind == "lethe", "the sword I swung last turn is forgotten this one")
        assert(not Combat.itemBlockReason(me, dagger), "the dagger is mine to use")
        assert(not Combat.itemBlockReason(me, me.char.unarmed), "and the fists are never forgotten")
        Combat.teleportUnit(c, me, 9, 1)
        assert(not Combat.itemBlockReason(me, sword), "step out of the haze and the sword is yours again")
        Combat.teleportUnit(c, me, 5, 7)
        assert(Combat.itemBlockReason(me, sword), "back in, refused again")
        wound(c, idOf(c, "character_lethe_drinker"), 9999)
        assert(not Combat.itemBlockReason(me, sword), "kill it first, and the river goes with it")
    end },

    { name = "Lethe Haze binds foes only, and a turn of only walking leaves the next one free", fn = function()
        local c = Fixture.combat(board(), hand(5, 7, { "weapon_iron_sword" }),
            { body("character_lethe_drinker", 5, 5), body("character_hungry_ghost", 5, 6) })
        local me, ghost = at(c, 5, 7), idOf(c, "character_hungry_ghost")
        local grasp = itemNamed(ghost.char, "weapon_hungry_grasp")
        openTurn(c, ghost)
        assert(Combat.useItem(c, ghost, grasp, me.x, me.y), "the ghost strikes")
        Lethe.turnOpened(ghost)
        assert(not Combat.itemBlockReason(ghost, grasp), "the river does not haze its own side")
        local sword = itemNamed(me.char, "weapon_iron_sword")
        openTurn(c, me)
        assert(Combat.useItem(c, me, sword, ghost.x, ghost.y), "I swing")
        Lethe.turnOpened(me)
        Lethe.turnOpened(me)
        assert(not Combat.itemBlockReason(me, sword), "a turn spent without it clears the memory")
    end },

    { name = "the Cup of Lethe hazes the wearer's foes within 2", fn = function()
        local c = Fixture.combat(board(), hand(5, 7, { "utility_cup_of_lethe" }), { body("character_hungry_ghost", 5, 6) })
        local me, ghost = at(c, 5, 7), idOf(c, "character_hungry_ghost")
        local grasp = itemNamed(ghost.char, "weapon_hungry_grasp")
        openTurn(c, ghost)
        assert(Combat.useItem(c, ghost, grasp, me.x, me.y), "the ghost strikes")
        Lethe.turnOpened(ghost)
        local block = Combat.itemBlockReason(ghost, grasp)
        assert(block and block.kind == "lethe", "beside the cup, it cannot strike the same way twice")
    end },

    -- ------------------------------------------------------------------------------ Never Full
    { name = "Never Full: a heal or a draught landing within 2 of a ghost is eaten, and the ghost is healed", fn = function()
        local c = Fixture.combat(board(), {
            hand(5, 7, { "ability_heal" }), hand(5, 8, { "consumable_healing_potion" }), hand(1, 1),
        }, { body("character_hungry_ghost", 5, 5, 100) })
        local priest, patient, far = at(c, 5, 7), at(c, 5, 8), at(c, 1, 1)
        local ghost = idOf(c, "character_hungry_ghost")
        wound(c, patient, 100); wound(c, ghost, 60); wound(c, far, 100)
        local p0, g0 = hp(patient), hp(ghost)
        openTurn(c, priest)
        assert(Combat.useItem(c, priest, itemNamed(priest.char, "ability_heal"), patient.x, patient.y), "the heal is cast")
        assert(hp(patient) > p0 and patient.y - ghost.y == 3, "three away, the patient is out of its reach")
        -- Bring the patient inside 2 and try again: the meal goes to the ghost.
        Combat.teleportUnit(c, patient, 5, 6)
        p0 = hp(patient)
        openTurn(c, priest)
        assert(Combat.useItem(c, priest, itemNamed(priest.char, "ability_heal"), patient.x, patient.y), "the heal is cast")
        assert(hp(patient) == p0, "the patient gets nothing")
        assert(hp(ghost) > g0, "the ghost is healed instead, and Grave-Cold does not turn it (it is a drink)")
        local g1 = hp(ghost)
        openTurn(c, patient)
        assert(Combat.useItem(c, patient, itemNamed(patient.char, "consumable_healing_potion"), patient.x, patient.y),
            "the draught is drunk")
        assert(hp(patient) == p0 and hp(ghost) > g1, "a draught is eaten too")
        local f0 = hp(far)
        Combat.applyHeal(c, far, 20)
        assert(hp(far) == f0 + 20, "heal away from them and it lands")
    end },

    { name = "the Pinhole Mouth eats only a foe's heal within 2", fn = function()
        local c = Fixture.combat(board(), { hand(5, 7, { "utility_pinhole_mouth" }, 100), hand(5, 8, {}, 100) },
            { body("character_hungry_ghost", 5, 5, 100) })
        local me, friend = at(c, 5, 7), at(c, 5, 8)
        local foe = idOf(c, "character_hungry_ghost")
        wound(c, me, 50); wound(c, friend, 50); wound(c, foe, 50)
        local m0, f0 = hp(me), hp(foe)
        -- The ghost would eat a heal on its own body's neighbour; strip its organ so only the Mouth is asked.
        foe.traits = {}
        Combat.applyHeal(c, foe, 20)
        assert(hp(foe) == f0 and hp(me) == m0 + 20, "the foe's heal comes to me")
        local fr0 = hp(friend)
        Combat.applyHeal(c, friend, 20)
        assert(hp(friend) == fr0 + 20, "my own side's heals pass untouched")
    end },

    -- ------------------------------------------------------------------------------ Two for One
    { name = "Two for One: three heads at the bell, and the jaws land once per head", fn = function()
        local c = Fixture.combat(board(), hand(3, 5, {}, 999), { body("character_lernaean_hydra", 4, 5, 210) })
        local me, hydra = at(c, 3, 5), idOf(c, "character_lernaean_hydra")
        assert(Lerna.heads(hydra) == 3, "it opens with three heads")
        local jaws = itemNamed(hydra.char, "weapon_hydra_jaws")
        assert(Lerna.strikes(hydra, jaws, jaws.activeAbility) == 3, "three heads, three bites")
        local before = Combat.tallyCount(me, "hitTaken")
        openTurn(c, hydra)
        assert(Combat.useItem(c, hydra, jaws, me.x, me.y), "it bites")
        assert(Combat.tallyCount(me, "hitTaken") - before == 3, "three blows land")
        assert(Status.get(hydra, "status_hydra_heads").def.stacks == 6, "the badge reads up to six")
    end },

    { name = "Two for One: a big slash takes a head and two grow back, up to six; a scratch or a hammer does not", fn = function()
        local c = Fixture.combat(board(), hand(1, 1), { body("character_lernaean_hydra", 5, 5, 200) })
        local foe, hydra = at(c, 1, 1), idOf(c, "character_lernaean_hydra")
        Combat.dealFlatDamage(c, hydra, 19, { "slash", "physical" }, "test", foe, { raw = true })
        assert(Lerna.heads(hydra) == 3, "under a tenth of its bar, nothing")
        Combat.dealFlatDamage(c, hydra, 30, { "impact", "physical" }, "test", foe, { raw = true })
        assert(Lerna.heads(hydra) == 3, "a hammer takes no head")
        Combat.dealFlatDamage(c, hydra, 20, { "slash", "physical" }, "test", foe, { raw = true })
        assert(Lerna.heads(hydra) == 4, "a tenth of its bar in one cut: one off, two back")
        for _ = 1, 4 do Combat.dealFlatDamage(c, hydra, 20, { "slash", "physical" }, "test", foe, { raw = true }) end
        assert(Lerna.heads(hydra) == 6, "never more than six")
    end },

    { name = "Two for One: fire or Burn cauterises, a cut then grows nothing, and the last head stays", fn = function()
        local c = Fixture.combat(board(), hand(1, 1), { body("character_lernaean_hydra", 5, 5, 400) })
        local foe, hydra = at(c, 1, 1), idOf(c, "character_lernaean_hydra")
        Combat.dealFlatDamage(c, hydra, 5, { "fire", "magical" }, "test", foe, { raw = true })
        assert(Status.has(hydra, "status_cauterised"), "fire seals the necks")
        assert(Status.get(hydra, "status_cauterised").remaining <= 10, "for two turns")
        for want = 2, 1, -1 do
            Combat.dealFlatDamage(c, hydra, 40, { "slash", "physical" }, "test", foe, { raw = true })
            assert(Lerna.heads(hydra) == want, "a cut takes a head and grows none: " .. want)
        end
        Combat.dealFlatDamage(c, hydra, 40, { "slash", "physical" }, "test", foe, { raw = true })
        assert(Lerna.heads(hydra) == 1, "the last head does not come off")
        Status.remove(c, hydra, "status_cauterised")
        Status.apply(c, hydra, "status_burn", { applier = foe })
        assert(Status.has(hydra, "status_cauterised"), "Burn landing on it cauterises too")
        Status.remove(c, hydra, "status_cauterised")
        Status.remove(c, hydra, "status_burn")
        Combat.dealFlatDamage(c, hydra, 40, { "slash", "physical" }, "test", foe, { raw = true })
        assert(Lerna.heads(hydra) == 2, "and once it wears off, two grow back again")
    end },

    -- ------------------------------------------------------------------------------ the Hydra's pieces
    { name = "Two Heads: each slash that strikes the wearer banks a strike (up to 3), spent on the next attack", fn = function()
        local c = Fixture.combat(board(), hand(5, 6, { "armor_two_heads", "weapon_iron_sword" }),
            { body("character_hungry_ghost", 5, 5, 999) })
        local me, ghost = at(c, 5, 6), idOf(c, "character_hungry_ghost")
        Combat.dealFlatDamage(c, me, 2, { "impact", "physical" }, "test", ghost, { raw = true })
        assert(Status.stacksOf(me, "status_two_heads") == 0, "a hammer banks nothing")
        for _ = 1, 4 do Combat.dealFlatDamage(c, me, 2, { "slash", "physical" }, "test", ghost, { raw = true }) end
        assert(Status.stacksOf(me, "status_two_heads") == 3, "up to three")
        local sword = itemNamed(me.char, "weapon_iron_sword")
        assert(Lerna.strikes(me, sword, sword.activeAbility) == 4, "the next swing lands four times")
        local before = Combat.tallyCount(ghost, "hitTaken")
        openTurn(c, me)
        assert(Combat.useItem(c, me, sword, ghost.x, ghost.y), "it swings")
        assert(Combat.tallyCount(ghost, "hitTaken") - before == 4, "four blows land")
        assert(Status.stacksOf(me, "status_two_heads") == 0, "and the bank is spent")
    end },

    { name = "Cauterise: Burn and an Unclosing Wound -- no heal, and no standing back up", fn = function()
        local c = Fixture.combat(board(), hand(5, 8, { "ability_cauterise" }), { body("character_hungry_ghost", 5, 5) })
        local me, ghost = at(c, 5, 8), idOf(c, "character_hungry_ghost")
        ghost.traits = {} -- a ghost would eat its own heal's neighbour; this case is about the wound
        openTurn(c, me)
        assert(Combat.useItem(c, me, itemNamed(me.char, "ability_cauterise"), ghost.x, ghost.y), "it is cast")
        assert(Status.has(ghost, "status_burn"), "the foe Burns")
        local w = Status.get(ghost, "status_unclosing_wound")
        assert(w and w.remaining <= 10, "and is Unclosing for two turns")
        wound(c, ghost, 10)
        local h = hp(ghost)
        Combat.applyHeal(c, ghost, 20)
        assert(hp(ghost) == h, "it cannot be healed")
    end },

    { name = "Cauterise stops an Archon's wisp raising its body, and the raise works once the wound is gone", fn = function()
        local a = unit("character_archer", 5, 5, { isolate = "bare", items = { Spirit.ORGAN }, stats = { health = 60 } })
        local c = Fixture.combat(board(), { hand(5, 6, { "ability_cauterise" }) }, { a })
        local me = at(c, 5, 6)
        local e = find(c, function(u) return u.side == "enemy" end)
        openTurn(c, me)
        assert(Combat.useItem(c, me, itemNamed(me.char, "ability_cauterise"), e.x, e.y), "it is cast")
        e.lastAttacker = me
        Combat.dealFlatDamage(c, e, 9999, { "physical" }, nil, me)
        assert(not e.alive and e.incapacitated, "the archon is down")
        local wisp = find(c, function(u) return u.alive and u.wispOf == e end)
        assert(wisp, "and throws its wisp")
        for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
            if Combat.footprintFree(c, 1, 1, e.x + d[1], e.y + d[2]) then
                Combat.teleportUnit(c, wisp, e.x + d[1], e.y + d[2]); break
            end
        end
        Trait.onAnyTurnEnd(c, wisp)
        assert(not e.alive and wisp.alive, "the body will not stand while it is Unclosing; the wisp waits")
        assert(not Combat.reanimate(c, e, 0.5), "and no revive stands it up either")
        Status.remove(c, e, "status_unclosing_wound")
        Trait.onAnyTurnEnd(c, wisp)
        assert(e.alive, "with the wound gone, the wisp raises it")
    end },

    { name = "Hydra's Blood: blows Poison, and a Poisoned foe that falls poisons every foe beside it", fn = function()
        local c = Fixture.combat(board(), { hand(5, 7, { "utility_hydras_blood", "weapon_iron_sword" }), hand(4, 5) }, {
            body("character_hungry_ghost", 5, 6, 300), body("character_hungry_ghost", 5, 5, 300),
            body("character_hungry_ghost", 6, 6, 300), body("character_hungry_ghost", 9, 9, 300),
        })
        local me, friend = at(c, 5, 7), at(c, 4, 5)
        local struck, above, beside, far = at(c, 5, 6), at(c, 5, 5), at(c, 6, 6), at(c, 9, 9)
        openTurn(c, me)
        assert(Combat.useItem(c, me, itemNamed(me.char, "weapon_iron_sword"), struck.x, struck.y), "it swings")
        assert(Status.has(struck, "status_poison"), "the blow Poisons")
        Combat.dealFlatDamage(c, struck, 9999, { "physical" }, "test", me, { raw = true })
        assert(not struck.alive, "the Poisoned foe falls")
        assert(Status.has(above, "status_poison") and Status.has(beside, "status_poison"),
            "its Poison spreads to every foe beside it")
        assert(not Status.has(far, "status_poison"), "not to a foe across the board")
        assert(not Status.has(friend, "status_poison"), "and never to the bearer's own side")
    end },

    -- ------------------------------------------------------------------------------ the fight
    { name = "The Grey Shore: one Drinker and one or two ghosts, on the underworld, with no rung", fn = function()
        local e = Encounter.get("encounter_the_grey_shore")
        assert(e and e.kind == "combat" and e.weight == 3, "an ordinary fight at weight 3")
        assert(e.rung == nil, "the bottom floor has no rung: the ground is the pin")
        assert(e.condition({ biome = "underworld" }) and not e.condition({ biome = "volcanic" }), "underworld only")
        local seen = {}
        for seed = 1, 40 do
            local list = e.composition({ biome = "underworld", depth = 15, seed = seed })
            local n = { character_lethe_drinker = 0, character_hungry_ghost = 0 }
            for _, id in ipairs(list) do
                assert(n[id], "only the Drinker and the ghosts: " .. tostring(id))
                n[id] = n[id] + 1
            end
            assert(n.character_lethe_drinker == 1, "one Drinker")
            assert(n.character_hungry_ghost >= 1 and n.character_hungry_ghost <= 2, "one or two ghosts")
            seen[n.character_hungry_ghost] = true
            assert(#list <= 4, "under the ordinary ceiling")
        end
        assert(seen[1] and seen[2], "both counts are dealt")
    end },
}
