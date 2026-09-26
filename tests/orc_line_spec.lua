-- Tests for THE ORCS OF WRATH (2026-09-26, reviewed over two rounds on "The Orcs of Wrath" artifact): the race,
-- its rule, the line's own mechanics, the fights and the drops.
--
--   Proven        a killing blow: +2 Damage and +2 Defense for the fight, three times
--   the bodies    the Hurler's hook, the Berserker's Blood Up, the Drummer's March, the Blood-Caller's
--                 offering, the Handler's chain and the War Ogre off it, the Pit-Fighter's Blood Ring (the
--                 alpha) and the Warchief's succession (the elite)
--   the drops     Orc Scars, the Unbroken Axe and Warpaint, Marching Drum, Blood Offering, Goad, the
--                 Pit-Fighter's Belt, the Heir's Torc and The Strongest Leads
-- Each case pins a rule the review approved, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local AI = require("models.ai")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local ORCS = {
    "character_orc_grunt", "character_orc_veteran", "character_orc_spear_hurler", "character_orc_berserker",
    "character_orc_war_drummer", "character_orc_blood_caller", "character_orc_beast_handler",
    "character_orc_pit_fighter", "character_orc_warchief",
}
local TROPHIES = {
    "utility_orc_scars", "weapon_unbroken_axe", "utility_warpaint", "ability_marching_drum",
    "ability_blood_offering", "ability_goad", "utility_pit_fighters_belt", "utility_heirs_torc",
    "ability_the_strongest_leads",
}
local ORGANS = {
    "utility_proven", "utility_blood_up", "utility_the_march", "utility_the_chain", "utility_holding_the_chain",
    "utility_the_blood_ring", "utility_warchiefs_presence", "utility_old_scars", "ability_hooked_spear",
}
local FIGHTS = {
    encounter_wrath_the_raiding_party = 1, encounter_wrath_the_march = 1, encounter_wrath_the_veterans = 1,
    encounter_wrath_the_driven_mob = 1, encounter_wrath_the_blood_ring = 1,
    encounter_wrath_the_blood_offering = 2, encounter_wrath_the_chained_ogre = 2,
    encounter_wrath_the_drums_of_war = 2, encounter_wrath_the_frenzy = 2, encounter_wrath_the_warchiefs_band = 2,
}

local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 300, health or 300
    return spawn
end

local function board(n) return Fixture.new(n or 11, n or 11) end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function all(c, id)
    local out = {}
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then out[#out + 1] = u end end
    return out
end

local function warband(spec, party)
    local enemies = {}
    for _, s in ipairs(spec) do enemies[#enemies + 1] = unit(s[1], s[2], s[3], s[4]) end
    return Fixture.combat(board(), party or walker(1, 1), enemies)
end

local function kill(c, victim, killer)
    Combat.dealFlatDamage(c, victim, 9999, { "physical" }, "test", killer, { raw = true })
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the orc is a race that hits hard and takes a blow, falls to the blade, and grants Proven",
        fn = function()
            local blueprint = Character.defs["character_orc_grunt"]
            local c = Character.instantiate("character_orc_grunt")
            assert(c.race == "orc" and c.kind == "humanoid", "an orc is a humanoid race")
            assert(c.resist.slash == -2 and c.resist.pierce == 1 and c.resist.impact == 1,
                "a blade opens them; an arrow and a club are turned")
            assert(c.resist.fire == nil, "no element: fire is this circle's ground")
            assert(c.stats.damage == blueprint.stats.damage + 1, "it hits hard")
            assert(c.stats.defense == blueprint.stats.defense + 1, "and takes a blow")
            assert(itemNamed(c, "utility_proven"), "the race put Proven in the grid")
            for _, id in ipairs(ORCS) do
                local def = Character.defs[id]
                assert(def and def.race == "orc", id .. " is an orc")
                assert(def.class and def.class ~= "knight", id .. " grows on a class, and not the knight table")
            end
            assert(Character.defs["character_war_ogre"].footprint.w == 2, "the War Ogre is a 2x2 body")
        end,
    },
    {
        name = "every orc trophy is an unstocked find an orc drops, on a real shelf; the organs are a body's own",
        fn = function()
            local dropped = {}
            for _, id in ipairs(ORCS) do
                for _, d in ipairs(Character.defs[id].drops or {}) do dropped[d] = true end
            end
            for _, id in ipairs(TROPHIES) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.unstocked, id .. " is a trophy: seen on the rack, never sold")
                assert(dropped[id], id .. " is on an orc's drop list")
                assert(def.class ~= "creature", id .. " sits on a real shelf")
            end
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal, id .. " is a body's own and cannot be taken")
                if def.type == "utility" then assert(def.bound, id .. " is an organ, bound to the body") end
            end
        end,
    },
    {
        name = "the ten fights stand on the flows, split across Wrath's floors, and the two elites are spares",
        fn = function()
            for id, rung in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e, id .. " exists")
                assert(e.rung == rung, id .. " stands on rung " .. rung)
                assert(e.condition({ biome = "volcanic" }) and not e.condition({ biome = "cave" }),
                    id .. " is locked to the flows")
            end
            assert(Encounter.get("encounter_wrath_the_blood_ring").kind == "elite", "the alpha's Blood Ring is an elite")
            assert(Encounter.get("encounter_wrath_the_warchiefs_band").kind == "elite", "the Warchief's Band is the elite")
            local wrath
            for _, s in ipairs(Descent.SINS) do if s.id == "wrath" then wrath = s end end
            local spares = {}
            for _, id in ipairs(wrath.elites.spares) do spares[id] = true end
            assert(spares.encounter_wrath_the_blood_ring and spares.encounter_wrath_the_warchiefs_band,
                "both are Wrath's spare elites")
        end,
    },
    -- ------------------------------------------------------------------------------ Proven
    {
        name = "Proven: a kill scars an orc, +2 Damage and +2 Defense, three times at most",
        fn = function()
            local c = warband({ { "character_orc_grunt", 5, 5 } },
                { walker(5, 6), walker(1, 1), walker(1, 3), walker(1, 5) })
            local grunt = one(c, "character_orc_grunt")
            local dmg, def = Combat.flatStat(grunt, "damage"), Combat.flatStat(grunt, "defense")
            kill(c, c.units[1], grunt)
            assert(Status.stacksOf(grunt, "status_proven") == 1, "one kill, one scar")
            assert(Combat.flatStat(grunt, "damage") == dmg + 2 and Combat.flatStat(grunt, "defense") == def + 2,
                "+2 Damage and +2 Defense")
            kill(c, c.units[2], grunt); kill(c, c.units[3], grunt); kill(c, c.units[4], grunt)
            assert(Status.stacksOf(grunt, "status_proven") == 3, "and never more than three")
        end,
    },
    {
        name = "Orc Scars: a kill makes a company body Proven",
        fn = function()
            local c = warband({ { "character_bandit", 5, 6 } },
                unit("character_archer", 5, 5, { isolate = "bare", items = { "utility_orc_scars" } }))
            local me = c.units[1]
            kill(c, c.units[2], me)
            assert(Status.stacksOf(me, "status_proven") == 1, "the bearer is Proven")
        end,
    },
    {
        name = "the Veteran opens the fight already Proven twice over",
        fn = function()
            local c = warband({ { "character_orc_veteran", 5, 5 } })
            local vet = one(c, "character_orc_veteran")
            -- The battle opens a body in its gear's boons (states/battle.lua); applied here the same way.
            for _, item in ipairs(Character.eachItem(vet.char)) do
                for _, b in ipairs(require("models.curse").openingBoons(item)) do Status.apply(c, vet, b.id, b.opts) end
            end
            assert(Status.stacksOf(vet, "status_proven") == 2, "two scars before a blow")
        end,
    },
    -- ------------------------------------------------------------------------------ the Berserker
    {
        name = "Blood Up: each turn it lands a hit it climbs; a turn that lands nothing leaves it Spent",
        fn = function()
            local c = warband({ { "character_orc_berserker", 5, 5 } }, walker(5, 6))
            local b = one(c, "character_orc_berserker")
            Trait.onCast(c, b, { damageDealt = 5 })
            Trait.onAnyTurnEnd(c, b)
            Trait.onCast(c, b, { damageDealt = 5 })
            Trait.onAnyTurnEnd(c, b)
            assert(Status.stacksOf(b, "status_blood_up") == 2, "two turns, two stacks")
            local init = b.initiative
            Trait.onAnyTurnEnd(c, b)
            assert(not Status.has(b, "status_blood_up"), "a dry turn breaks the streak")
            assert(Status.has(b, "status_spent") and b.initiative > init, "and its next turn comes later")
        end,
    },
    {
        name = "Blood Up: with no foe in reach, the Berserker hits the nearest body, orc included",
        fn = function()
            local c = warband({ { "character_orc_berserker", 5, 5 }, { "character_orc_grunt", 5, 6 } }, walker(1, 11))
            local b, kin = one(c, "character_orc_berserker"), one(c, "character_orc_grunt")
            Status.apply(c, b, "status_blood_up")
            b.char.stats.movement = 0
            openTurn(c, b)
            local plan = AI.plan(c, b)
            assert(plan and plan.reason == "blood up", "the streak decides the turn")
            assert(Combat.unitAt(c, plan.tx, plan.ty) == kin, "and the blow is aimed at the Grunt beside it")
        end,
    },
    {
        name = "the Unbroken Axe and Warpaint: the streak climbs, and worn together the longer counts, not both",
        fn = function()
            local c = warband({ { "character_bandit", 9, 9 } },
                unit("character_archer", 5, 5, { isolate = "bare", items = { "weapon_unbroken_axe", "utility_warpaint" } }))
            local me = c.units[1]
            local axe = itemNamed(me.char, "weapon_unbroken_axe")
            for _ = 1, 2 do
                Trait.onCast(c, me, { item = axe, damageDealt = 5 })
                Trait.onAnyTurnEnd(c, me)
            end
            assert(Status.stacksOf(me, "status_unbroken") == 2, "two turns in a row, two stacks -- not four")
            Trait.onAnyTurnEnd(c, me)
            assert(not Status.has(me, "status_unbroken"), "a turn without a hit resets it")
        end,
    },
    -- ------------------------------------------------------------------------------ the Drummer
    {
        name = "the March: the drum is marked a turn ahead, then every orc steps toward its nearest foe",
        fn = function()
            local c = warband({ { "character_orc_war_drummer", 2, 2 }, { "character_orc_grunt", 5, 2 } }, walker(5, 9))
            local drum, grunt = one(c, "character_orc_war_drummer"), one(c, "character_orc_grunt")
            Trait.onAnyTurnEnd(c, drum)
            assert(Status.has(drum, "status_drumbeat"), "the beat shows first")
            assert(grunt.y == 2, "and nobody has moved")
            Trait.onAnyTurnEnd(c, drum)
            assert(grunt.y == 3, "then the Grunt steps toward the foe")
            assert(not Status.has(drum, "status_drumbeat"), "and the beat is spent")
        end,
    },
    {
        name = "Marching Drum: every ally steps toward its own nearest foe, where the drum says",
        fn = function()
            local c = warband({ { "character_bandit", 5, 10 } },
                { unit("character_archer", 5, 2, { isolate = "bare", items = { "ability_marching_drum" } }), walker(8, 5) })
            local me, ally, foe = c.units[1], nil, one(c, "character_bandit")
            for _, u in ipairs(c.units) do if u.side == me.side and u ~= me then ally = u end end
            local before = Combat.unitGap(ally, foe)
            openTurn(c, me)
            assert(Combat.useItem(c, me, itemNamed(me.char, "ability_marching_drum"), me.x, me.y), "the drum is beaten")
            assert(me.y == 3, "the drummer steps toward the foe")
            assert(Combat.unitGap(ally, foe) < before, "and so does the ally")
        end,
    },
    -- ------------------------------------------------------------------------------ the Blood-Caller
    {
        name = "Blood Offering: the caller pays 15% of its health; the ally heals that much and is Proven",
        fn = function()
            local c = warband({ { "character_orc_blood_caller", 5, 5 }, { "character_orc_grunt", 5, 7 } }, walker(1, 1))
            local caller, kin = one(c, "character_orc_blood_caller"), one(c, "character_orc_grunt")
            kin.char.stats.health.current = 5
            local before = hp(caller)
            openTurn(c, caller)
            assert(Combat.useItem(c, caller, itemNamed(caller.char, "ability_blood_offering"), kin.x, kin.y))
            local paid = before - hp(caller)
            assert(paid > 0, "the caller bleeds")
            assert(hp(kin) == 5 + paid, "the ally heals by what was paid")
            assert(Status.stacksOf(kin, "status_proven") == 1, "and is Proven without a kill")
        end,
    },
    -- ------------------------------------------------------------------------------ the chain
    {
        name = "the Chain: the ogre goes for what its Handler struck, and is dragged back if it strays",
        fn = function()
            local c = warband({ { "character_orc_beast_handler", 2, 2 }, { "character_war_ogre", 8, 8 } },
                walker(2, 3))
            local foe = c.units[1]
            local handler, ogre = one(c, "character_orc_beast_handler"), one(c, "character_war_ogre")
            Trait.onCast(c, handler, { damageDealt = 4, tx = foe.x, ty = foe.y })
            assert(ogre.pointedAt == foe, "the Handler points, and the ogre looks where it points")
            Trait.onAnyTurnEnd(c, ogre)
            assert(Combat.unitGap(ogre, handler) <= 3, "the chain drags it back beside the Handler")
        end,
    },
    {
        name = "Unchained: with its Handler dead the ogre hits harder, and hits whoever is nearest",
        fn = function()
            local c = warband({ { "character_orc_beast_handler", 9, 9 }, { "character_war_ogre", 2, 2 },
                { "character_orc_grunt", 4, 2 } }, walker(9, 2))
            local foe = c.units[1]
            local handler, ogre, grunt = one(c, "character_orc_beast_handler"), one(c, "character_war_ogre"),
                one(c, "character_orc_grunt")
            local before = Combat.flatStat(ogre, "damage")
            kill(c, handler, foe)
            assert(Status.has(ogre, "status_unchained"), "the chain is off")
            assert(Combat.flatStat(ogre, "damage") > before, "and it hits harder")
            openTurn(c, ogre)
            local plan = AI.plan(c, ogre)
            assert(plan and plan.reason == "unchained", "the rampage decides its turn")
            assert(Combat.unitAt(c, plan.tx, plan.ty) == grunt, "and the nearest body is an orc")
        end,
    },
    {
        name = "Goad: the ally pays a tenth of its health, acts again at once, and its next blow is empowered",
        fn = function()
            local c = warband({ { "character_orc_beast_handler", 5, 5 }, { "character_war_ogre", 6, 5 } }, walker(1, 1))
            local handler, ogre = one(c, "character_orc_beast_handler"), one(c, "character_war_ogre")
            local before = hp(ogre)
            openTurn(c, handler)
            assert(Combat.useItem(c, handler, itemNamed(handler.char, "ability_goad"), ogre.x, ogre.y))
            assert(hp(ogre) < before, "the goad draws blood")
            assert((ogre.extraActions or 0) >= 1, "and the ogre acts again")
            assert(Status.has(ogre, "status_empowered"), "with its next blow empowered")
        end,
    },
    -- ------------------------------------------------------------------------------ the Blood Ring
    {
        name = "the Blood Ring: the crowd lines the edge and watches; the Pit-Fighter names the strongest foe",
        fn = function()
            local c = warband({ { "character_orc_pit_fighter", 6, 6 }, { "character_orc_grunt", 6, 4 },
                { "character_orc_grunt", 4, 6 } }, { walker(6, 8, 300), walker(8, 6, 100) })
            local strong = c.units[1]
            local pit = one(c, "character_orc_pit_fighter")
            for _, g in ipairs(all(c, "character_orc_grunt")) do
                assert(Status.has(g, "status_spectating"), "the Grunt is in the crowd")
                assert(g.x == 1 or g.y == 1 or g.x == 11 or g.y == 11, "at the ring's edge")
                openTurn(c, g)
                local plan = AI.plan(c, g)
                assert(plan and plan.wait, "and it only watches")
            end
            assert(Status.get(pit, "status_the_challenge").exempt == strong, "the most health is the challenger")
            assert(Status.has(strong, "status_challenger"), "and wears the mark")
        end,
    },
    {
        name = "the Challenge: the Pit-Fighter takes half from everyone but the challenger",
        fn = function()
            local c = warband({ { "character_orc_pit_fighter", 6, 6 } }, { walker(6, 8, 300), walker(8, 6, 100) })
            local strong, weak = c.units[1], c.units[2]
            local pit = one(c, "character_orc_pit_fighter")
            local full = hp(pit)
            Combat.dealFlatDamage(c, pit, 40, { "physical" }, "test", strong)
            local fromChallenger = full - hp(pit)
            local mid = hp(pit)
            Combat.dealFlatDamage(c, pit, 40, { "physical" }, "test", weak)
            local fromOther = mid - hp(pit)
            assert(fromChallenger > 0 and fromOther > 0, "both blows land")
            assert(fromOther * 2 <= fromChallenger + 1, "the other's blow lands at half")
        end,
    },
    {
        name = "the Crowd: ending a turn beside it shoves you back and hurts; a fall sends one in",
        fn = function()
            local c = warband({ { "character_orc_pit_fighter", 6, 6 }, { "character_orc_grunt", 6, 1 },
                { "character_orc_grunt", 1, 6 } }, { walker(6, 8, 300), walker(8, 8, 100) })
            local near, other = c.units[1], c.units[2]
            local watcher
            for _, g in ipairs(all(c, "character_orc_grunt")) do if g.y == 1 then watcher = g end end
            assert(watcher, "a Grunt stands at the top edge")
            Combat.teleportUnit(c, near, watcher.x, watcher.y + 1, { silent = true })
            local before = hp(near)
            Trait.onAnyTurnEnd(c, near)
            assert(Combat.unitGap(near, watcher) > 1, "shoved back into the ring")
            assert(hp(near) < before, "and struck")
            kill(c, other, one(c, "character_orc_pit_fighter"))
            local stepped = 0
            for _, g in ipairs(all(c, "character_orc_grunt")) do
                if not Status.has(g, "status_spectating") then stepped = stepped + 1 end
            end
            assert(stepped == 1, "a body fell, and one of the crowd steps in")
        end,
    },
    {
        name = "the Pit-Fighter's Belt: half from every foe but the one you last struck",
        fn = function()
            local c = warband({ { "character_bandit", 5, 6 }, { "character_bandit", 7, 7 } },
                unit("character_archer", 5, 5, { isolate = "bare", items = { "utility_pit_fighters_belt" } }))
            local me, struck, other = c.units[1], c.units[2], c.units[3]
            me.char.stats.health.max, me.char.stats.health.current = 500, 500
            Trait.onCast(c, me, { damageDealt = 3, tx = struck.x, ty = struck.y })
            local a = hp(me)
            Combat.dealFlatDamage(c, me, 40, { "physical" }, "test", struck)
            local fromStruck = a - hp(me)
            local b = hp(me)
            Combat.dealFlatDamage(c, me, 40, { "physical" }, "test", other)
            local fromOther = b - hp(me)
            assert(fromOther * 2 <= fromStruck + 1, "the one you did not strike lands at half")
        end,
    },
    -- ------------------------------------------------------------------------------ the Warchief
    {
        name = "the Strongest Leads: the Warchief falls, and the most-Proven orc heals and takes up his lead",
        fn = function()
            local c = warband({ { "character_orc_warchief", 5, 5 }, { "character_orc_grunt", 5, 3 },
                { "character_orc_grunt", 3, 5 } }, walker(9, 9))
            local foe = c.units[1]
            local chief = one(c, "character_orc_warchief")
            local grunts = all(c, "character_orc_grunt")
            local scarred, plain = grunts[1], grunts[2]
            Status.apply(c, scarred, "status_proven", { magnitude = 2 })
            scarred.char.stats.health.current = 5
            kill(c, chief, foe)
            assert(hp(scarred) > 5, "the scarred Grunt heals")
            assert(Trait.has(scarred, "trait_the_strongest_leads"), "and leads now")
            assert(not Trait.has(plain, "trait_the_strongest_leads"), "the fresh one does not")
            local dmg = Combat.flatStat(plain, "damage")
            Status.remove(c, plain, "status_proven")
            plain.x, plain.y = scarred.x + 1, scarred.y
            assert(Combat.flatStat(plain, "damage") >= dmg, "and its Presence reaches the one beside it")
        end,
    },
    {
        name = "the Heir's Torc: an ally falls, and the bearer heals and takes up its fight",
        fn = function()
            local c = warband({ { "character_bandit", 9, 9 } },
                { unit("character_archer", 5, 5, { isolate = "bare", items = { "utility_heirs_torc" } }), walker(5, 7) })
            local me, ally, foe = c.units[1], c.units[2], c.units[3]
            me.char.stats.health.current = 5
            kill(c, ally, foe)
            assert(hp(me) > 5, "the bearer heals")
            assert(Status.stacksOf(me, "status_taken_up") == 1, "and takes up the fight")
        end,
    },
    {
        name = "The Strongest Leads: cast, then fall, and your boons pass to the ally with the most health",
        fn = function()
            local c = warband({ { "character_bandit", 9, 9 } },
                { unit("character_archer", 5, 5, { isolate = "bare", items = { "ability_the_strongest_leads" } }),
                  walker(5, 7, 300), walker(7, 5, 50) })
            local me, strong, weak, foe = c.units[1], c.units[2], c.units[3], c.units[4]
            openTurn(c, me)
            assert(Combat.useItem(c, me, itemNamed(me.char, "ability_the_strongest_leads"), me.x, me.y))
            Status.apply(c, me, "status_proven", { magnitude = 2 })
            strong.char.stats.health.current = 200
            kill(c, me, foe)
            assert(Status.stacksOf(strong, "status_proven") == 2, "the boons pass to the strongest ally")
            assert(Status.stacksOf(weak, "status_proven") == 0, "not to the weaker one")
            assert(hp(strong) > 200, "who heals")
        end,
    },
    -- ------------------------------------------------------------------------------ the Hurler
    {
        name = "the Hooked Spear: a hit drags the target in beside the Hurler",
        fn = function()
            local c = warband({ { "character_orc_spear_hurler", 5, 2 } }, walker(5, 6))
            local foe, hurler = c.units[1], one(c, "character_orc_spear_hurler")
            local before = hp(foe)
            openTurn(c, hurler)
            assert(Combat.useItem(c, hurler, itemNamed(hurler.char, "ability_hooked_spear"), foe.x, foe.y))
            assert(hp(foe) < before, "the spear lands")
            assert(Combat.unitGap(foe, hurler) == 1, "and the target is dragged in beside it")
        end,
    },
}
