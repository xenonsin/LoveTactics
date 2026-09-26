-- Tests for THE GOBLINS OF WRATH (2026-09-26, reviewed over two rounds on "The Goblins of Wrath" artifact): the
-- race, its rules, the line's own mechanics, the fights and the drops.
--
--   Blood Feud    whoever last hit a goblin is the Feud: +2 from every goblin, and one that can reach it
--                 attacks nothing else; the mark moves to the next foe to hit a goblin
--   Mob Courage   a goblin with no kin within 2 cowers; the elite band never does
--   the bodies    the Cutter's Toss, the Firebrand's wraps, the Fanatic's Spin Out, the Brute's Pent Up, the
--                 Hexer's Red Mist, the Redcap's scent and cap, the Wolf-Rider's two halves, the Bugbear's
--                 ambush, the Hobgoblin's orders, and the King's Rigged Hall
-- Each case pins a rule the review approved, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local AI = require("models.ai")
local Feud = require("models.feud")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local GOBLINS = {
    "character_goblin_cutter", "character_goblin_sapper", "character_goblin_firebrand", "character_goblin_brute",
    "character_goblin_fanatic", "character_goblin_hexer", "character_goblin_wolf_rider", "character_redcap",
    "character_bugbear", "character_hobgoblin", "character_goblin_king",
}
local TROPHIES = {
    "ability_toss", "utility_firewalkers_wraps", "ability_spin_out", "ability_bottled_rage", "ability_red_mist",
    "utility_dipped_cap", "weapon_redcaps_pike", "utility_ambushers_hood", "weapon_hobgoblins_lash",
    "ability_kings_lever",
}
local FIGHTS = {
    encounter_wrath_the_warband = 1, encounter_wrath_the_red_mist = 1, encounter_wrath_the_hobgoblins_mob = 1,
    encounter_wrath_the_fanatics = 2, encounter_wrath_the_redcaps = 2, encounter_wrath_the_goblin_kings_court = 2,
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

-- A board of goblins (enemy side) and a company.
local function warband(spec, party)
    local enemies = {}
    for _, s in ipairs(spec) do enemies[#enemies + 1] = unit(s[1], s[2], s[3], s[4]) end
    return Fixture.combat(board(), party or walker(1, 1), enemies)
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the goblin is a race that hits hard and first, falls to the bow, and grants Blood Feud",
        fn = function()
            local blueprint = Character.defs["character_goblin_cutter"]
            local c = Character.instantiate("character_goblin_cutter")
            assert(c.race == "goblin" and c.kind == "humanoid", "a goblin is a humanoid race")
            assert(c.resist.pierce == -2 and c.resist.slash == 1 and c.resist.impact == 1,
                "an arrow finds them; a blade and a club are turned")
            assert(c.resist.fire == nil, "no element: fire is this circle's ground")
            assert(c.stats.damage == blueprint.stats.damage + 1, "it hits hard")
            assert(c.stats.speed == blueprint.stats.speed + 1, "and first")
            assert(itemNamed(c, "utility_blood_feud"), "the race put Blood Feud in the grid")
            local grant = Item.defs["utility_blood_feud"]
            assert(grant.bound and grant.noSteal, "Blood Feud is an organ, never kit")
            for _, id in ipairs(GOBLINS) do
                local def = Character.defs[id]
                assert(def and def.race == "goblin", id .. " is a goblin")
                assert(def.class, id .. " appends to a class")
                assert(def.class ~= "knight", id .. " is not on the knight table (it walls a line body at depth)")
            end
        end,
    },
    {
        name = "every goblin trophy is an unstocked find a goblin carries or drops, and works on any floor",
        fn = function()
            local dropped = {}
            for _, id in ipairs(GOBLINS) do
                for _, d in ipairs(Character.defs[id].drops or {}) do dropped[d] = true end
            end
            for _, id in ipairs(TROPHIES) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.unstocked, id .. " is a trophy: seen on the rack, never sold")
                assert(dropped[id], id .. " is on a goblin's drop list")
                assert(def.class ~= "creature", id .. " sits on a real shelf")
            end
        end,
    },
    {
        name = "the six fights stand on the volcanic ground, split across Wrath's two floors, and the elites are spares",
        fn = function()
            for id, rung in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e, id .. " exists")
                assert(e.rung == rung, id .. " stands on rung " .. rung)
                assert(e.condition({ biome = "volcanic" }) and not e.condition({ biome = "cave" }),
                    id .. " is locked to the flows")
            end
            local wrath
            for _, s in ipairs(Descent.SINS) do if s.id == "wrath" then wrath = s end end
            local spares = {}
            for _, id in ipairs(wrath.elites.spares) do spares[id] = true end
            assert(spares.encounter_wrath_the_hobgoblins_mob and spares.encounter_wrath_the_goblin_kings_court
                and spares.encounter_wrath_the_redcaps,
                "the Hobgoblin's Mob, the King's Court and the Redcaps are Wrath's spare elites")
            assert(Encounter.get("encounter_wrath_the_redcaps").kind == "elite",
                "the Redcaps is an elite: an assassin's table out-turns an ordinary fight")
        end,
    },
    {
        name = "the goblins' own kit is a body's organ or order, never shelved",
        fn = function()
            for _, id in ipairs({ "utility_blood_feud", "utility_pent_up", "utility_unsteered", "utility_drying_cap",
                "utility_war_saddle", "ability_blood_scent", "ability_name_the_enemy", "ability_the_lash",
                "ability_rigged_hall", "ability_toss_a_goblin", "ability_cage_lever", "ability_from_hiding" }) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.class == "creature" and def.noSteal, id .. " is a body's own and cannot be taken")
                if def.type == "utility" then assert(def.bound, id .. " is an organ, bound to the body") end
            end
            assert(Item.defs["utility_unsteered"].statusImmunity, "nobody steers a Fanatic")
        end,
    },
    -- ------------------------------------------------------------------------------ Blood Feud
    {
        name = "Blood Feud: a goblin struck marks its striker; the next foe to strike one takes the mark",
        fn = function()
            local c = warband({ { "character_goblin_cutter", 5, 6 }, { "character_goblin_cutter", 8, 8 } },
                { walker(5, 5), walker(8, 9) })
            local a, b = c.units[1], c.units[2]
            local g1 = one(c, "character_goblin_cutter")
            local g2 = c.units[4]
            Combat.dealFlatDamage(c, g1, 3, { "physical" }, "test", a)
            assert(Feud.of(c, g1.side) == a, "the first striker is the Feud")
            Combat.dealFlatDamage(c, g2, 3, { "physical" }, "test", b)
            assert(Feud.of(c, g1.side) == b, "the mark moves to the next striker")
            assert(not Status.has(a, "status_blood_feud"), "and leaves the first")
            local item = itemNamed(g1.char, "weapon_iron_axe")
            local vsFeud = Trait.outgoingDamageBonus(c, g1, b, item, item.tags)
            local vsOther = Trait.outgoingDamageBonus(c, g1, a, item, item.tags)
            assert(vsFeud - vsOther == 2, "every goblin deals +2 to the Feud")
        end,
    },
    {
        name = "Blood Feud: a goblin that can reach the Feud goes for it over a nearer foe",
        fn = function()
            local c = warband({ { "character_goblin_cutter", 5, 5 } }, { walker(5, 6), walker(7, 5) })
            local near, feud = c.units[1], c.units[2]
            local g = one(c, "character_goblin_cutter")
            Feud.mark(c, feud, g)
            openTurn(c, g)
            local plan = AI.plan(c, g)
            assert(plan and plan.reason == "blood feud", "the Feud decides the turn")
            local tx, ty = plan.tx, plan.ty
            assert(Combat.unitAt(c, tx, ty) == feud or (math.abs(tx - feud.x) + math.abs(ty - feud.y)) <= 1,
                "and the blow is aimed at the Feud, not at the foe beside it")
        end,
    },
    {
        name = "Mob Courage: a goblin with no kin within 2 cowers; the alpha never does",
        fn = function()
            local c = warband({ { "character_goblin_cutter", 2, 9 }, { "character_goblin_cutter", 9, 9 },
                { "character_hobgoblin", 9, 2 } }, walker(1, 1))
            Trait.onAnyTurnEnd(c, c.units[1])
            local lone = one(c, "character_goblin_cutter")
            local hob = one(c, "character_hobgoblin")
            assert(Status.has(lone, "status_cowering"), "alone, a goblin cowers")
            assert(not Status.has(hob, "status_cowering"), "the alpha is not afraid of being alone")
            local c2 = warband({ { "character_goblin_cutter", 5, 5 }, { "character_goblin_cutter", 5, 7 } }, walker(1, 1))
            Trait.onAnyTurnEnd(c2, c2.units[1])
            assert(not Status.has(one(c2, "character_goblin_cutter"), "status_cowering"), "with kin beside it, it holds")
        end,
    },
    -- ------------------------------------------------------------------------------ the kit
    {
        name = "Toss: the weapon beside it is thrown for its damage, lands by the foe, and comes back when walked over",
        fn = function()
            local c = warband({ { "character_goblin_cutter", 5, 2 } }, walker(5, 6))
            local foe, g = c.units[1], one(c, "character_goblin_cutter")
            local axe = itemNamed(g.char, "weapon_iron_axe")
            local before = hp(foe)
            local ok = Fixture.strike(c, g, foe, "ability_toss")
            assert(ok, "the throw is made")
            assert(hp(foe) < before, "the axe lands for damage")
            local block = Combat.itemBlockReason(g, axe)
            assert(block and block.kind == "tossed", "the axe is gone from its cell")
            local pile
            for _, h in ipairs(c.hazards or {}) do if h.alive and h.id == "hazard_tossed_weapon" then pile = h end end
            assert(pile, "it lies on the ground by the foe")
            g.x, g.y = pile.x, pile.y
            Hazard.onEnter(c, g, pile.x, pile.y)
            assert(not Combat.itemBlockReason(g, axe), "walked over, it is back in hand")
        end,
    },
    {
        name = "Firewalker's Wraps: fire underfoot does not burn, the tile left catches, and standing in fire hits harder",
        fn = function()
            local c = warband({ { "character_goblin_firebrand", 5, 5 } }, walker(1, 1))
            local g = one(c, "character_goblin_firebrand")
            assert(Trait.flag(g, "emberwalk"), "burning ground does not harm it")
            assert(Item.defs["utility_firewalkers_wraps"].trail.hazard == "hazard_fire", "the tile it steps off catches")
            local dry = Trait.liveBonus(g, "damage")
            Hazard.place(c, 5, 5, "hazard_fire", {})
            assert(Trait.liveBonus(g, "damage") - dry == 3, "+3 damage standing in fire")
        end,
    },
    {
        name = "Spin Out: a turn's wind-up, then three tiles along the lane, striking every body beside the path, allies too",
        fn = function()
            local c = warband({ { "character_goblin_fanatic", 2, 5 }, { "character_goblin_cutter", 4, 6 } },
                walker(5, 4))
            local foe = c.units[1]
            local fan, kin = one(c, "character_goblin_fanatic"), one(c, "character_goblin_cutter")
            local foeBefore, kinBefore = hp(foe), hp(kin)
            openTurn(c, fan)
            assert(Combat.useItem(c, fan, itemNamed(fan.char, "ability_spin_out"), 3, 5), "it picks a lane and winds up")
            assert(fan.x == 2, "nothing moves until the wind-up is done")
            assert(Combat.resolveChannel(c, fan), "and it spins")
            assert(fan.x == 5 and fan.y == 5, "three tiles along the lane")
            assert(hp(foe) < foeBefore, "the foe beside the path is struck")
            assert(hp(kin) < kinBefore, "and so is the goblin beside it")
        end,
    },
    {
        name = "Pent Up: every hit adds Seething; at three it is Primed; dead, it bursts on everything beside it",
        fn = function()
            local c = warband({ { "character_goblin_brute", 5, 5 } }, walker(5, 6))
            local foe, brute = c.units[1], one(c, "character_goblin_brute")
            for _ = 1, 3 do Combat.dealFlatDamage(c, brute, 1, { "physical" }, "test", foe) end
            assert(Status.has(brute, "status_primed"), "three hits and it is Primed")
            local before = hp(foe)
            Combat.dealFlatDamage(c, brute, 999, { "physical" }, "test", foe, { raw = true })
            assert(not brute.alive, "the Brute falls")
            assert(hp(foe) < before, "and the burst reaches whoever stood beside it")
            assert(Hazard.at(c, 5, 4, "hazard_fire"), "the tiles around it are left burning")
        end,
    },
    {
        name = "Red Mist: inside it a body rolls a random action on any target, and a company body is taken out of hand",
        fn = function()
            local c = warband({ { "character_goblin_hexer", 5, 2 }, { "character_goblin_cutter", 5, 7 } }, walker(5, 6))
            local foe, hexer = c.units[1], one(c, "character_goblin_hexer")
            openTurn(c, hexer)
            assert(Combat.useItem(c, hexer, itemNamed(hexer.char, "ability_red_mist"), 5, 6), "the mist is laid")
            assert(Status.has(foe, "status_seeing_red"), "the company body inside is Seeing Red")
            assert(foe.control == "ai", "and the game takes its turn")
            openTurn(c, foe)
            local plan = AI.plan(c, foe)
            assert(plan and plan.reason == "seeing red", "its turn is a roll, not a choice")
            Status.remove(c, foe, "status_seeing_red")
            assert(foe.control ~= "ai" or foe._seeRedControl == "ai", "and it is handed back when the red clears")
        end,
    },
    {
        name = "the Redcap: blinks to a wounded foe and back; a dry turn costs it, a kill wets the cap",
        fn = function()
            local c = warband({ { "character_redcap", 2, 2 } }, walker(5, 5))
            local foe, cap = c.units[1], one(c, "character_redcap")
            local scent = itemNamed(cap.char, "ability_blood_scent")
            openTurn(c, cap)
            local before = hp(foe)
            Combat.useItem(c, cap, scent, foe.x, foe.y)
            assert(hp(foe) == before, "a healthy foe has no scent")
            foe.char.stats.health.current = 100
            openTurn(c, cap)
            assert(Combat.useItem(c, cap, scent, foe.x, foe.y), "a foe below half is found")
            assert(hp(foe) < 100, "and struck")
            assert(cap.x == 2 and cap.y == 2, "and the Redcap is back where it stood")
            cap._capWet = nil
            local full = hp(cap)
            Trait.onAnyTurnEnd(c, cap)
            assert(hp(cap) < full, "a turn that drew no blood dries the cap")
        end,
    },
    {
        name = "the Dipped Cap: a kill turns you Invisible and makes the next blow on a wounded foe certain",
        fn = function()
            local c = warband({ { "character_bandit", 5, 6 }, { "character_bandit", 7, 7 } },
                unit("character_archer", 5, 5, { isolate = "bare", items = { "utility_dipped_cap" } }))
            local me, victim, next_ = c.units[1], c.units[2], c.units[3]
            Combat.dealFlatDamage(c, victim, 9999, { "physical" }, "test", me, { raw = true })
            assert(not victim.alive, "the kill")
            assert(Status.has(me, "status_invisible") and Status.has(me, "status_dipped"), "vanish, and the cap is wet")
            next_.char.stats.health.current = 1
            openTurn(c, me)
            assert(Combat.forcesCrit(c, me, next_, Item.instantiate("weapon_iron_dagger")), "the next wounded foe is certain")
        end,
    },
    {
        name = "the Wolf-Rider: shot from range the wolf goes wild; cut down up close the rider fights on",
        fn = function()
            local c = warband({ { "character_goblin_wolf_rider", 5, 8 } }, walker(5, 2))
            local archer, rider = c.units[1], one(c, "character_goblin_wolf_rider")
            Combat.dealFlatDamage(c, rider, 9999, { "pierce" }, "test", archer, { raw = true })
            assert(rider.alive and rider.char.id == "character_wolf_grunt", "the rider falls and the wolf fights on")
            assert(Status.has(rider, "status_seeing_red"), "wild")
            local c2 = warband({ { "character_goblin_wolf_rider", 5, 6 } }, walker(5, 5))
            local swordsman, rider2 = c2.units[1], one(c2, "character_goblin_wolf_rider")
            Combat.dealFlatDamage(c2, rider2, 9999, { "slash" }, "test", swordsman, { raw = true })
            assert(rider2.alive and rider2.char.id == "character_goblin_cutter", "the wolf falls and the rider rolls clear")
        end,
    },
    {
        name = "the Hobgoblin names the Feud, and its lash sends a goblin again at once",
        fn = function()
            local c = warband({ { "character_hobgoblin", 5, 3 }, { "character_goblin_cutter", 5, 4 } },
                { walker(5, 7), walker(2, 2) })
            local target = c.units[1]
            local hob, kin = one(c, "character_hobgoblin"), one(c, "character_goblin_cutter")
            openTurn(c, hob)
            assert(Combat.useItem(c, hob, itemNamed(hob.char, "ability_name_the_enemy"), target.x, target.y))
            assert(Feud.of(c, hob.side) == target, "the Hobgoblin picks the Feud")
            local before = hp(kin)
            openTurn(c, hob)
            assert(Combat.useItem(c, hob, itemNamed(hob.char, "ability_the_lash"), kin.x, kin.y), "the lash lands")
            assert(hp(kin) < before, "for a tenth of its health")
            assert((kin.extraActions or 0) >= 1, "and it acts again")
        end,
    },
    {
        name = "From Hiding: opened unseen, the Bugbear's blow is doubled and Stuns; seen, it is only a blow",
        fn = function()
            local c = warband({ { "character_bugbear", 5, 6 } }, walker(5, 5))
            local foe, bear = c.units[1], one(c, "character_bugbear")
            local hide = itemNamed(bear.char, "ability_from_hiding")
            openTurn(c, bear)
            bear.openedUnseen = true
            local before = hp(foe)
            assert(Combat.useItem(c, bear, hide, foe.x, foe.y))
            local unseen = before - hp(foe)
            assert(Status.has(foe, "status_stun"), "out of hiding, it Stuns")
            Status.remove(c, foe, "status_stun")
            openTurn(c, bear)
            bear.openedUnseen = false
            before = hp(foe)
            assert(Combat.useItem(c, bear, hide, foe.x, foe.y))
            assert(before - hp(foe) < unseen, "seen, the same blow is smaller")
            assert(not Status.has(foe, "status_stun"), "and stuns nobody")
        end,
    },
    {
        name = "the King's reach: he throws a goblin beside him onto a foe, and his cage lets a Fanatic loose",
        fn = function()
            local c = warband({ { "character_goblin_king", 5, 2 }, { "character_goblin_cutter", 5, 3 } }, walker(5, 7))
            local foe = c.units[1]
            local king, kin = one(c, "character_goblin_king"), one(c, "character_goblin_cutter")
            local before = hp(foe)
            openTurn(c, king)
            assert(Combat.useItem(c, king, itemNamed(king.char, "ability_toss_a_goblin"), foe.x, foe.y), "he throws")
            assert(hp(foe) < before, "the foe takes the landing")
            assert(Combat.unitGap(kin, foe) == 1, "and the goblin lands beside it")
            openTurn(c, king)
            assert(Combat.useItem(c, king, itemNamed(king.char, "ability_cage_lever"), king.x, king.y), "a cage opens")
            assert(one(c, "character_goblin_fanatic"), "and a Fanatic is loose")
        end,
    },
    {
        name = "the Rigged Hall: a marked row, a turn later, downs everyone on it -- the King's own court included",
        fn = function()
            local c = warband({ { "character_goblin_king", 5, 2 }, { "character_goblin_cutter", 4, 6 } },
                { walker(5, 6), walker(9, 9) })
            local onRow, clear = c.units[1], c.units[2]
            local king, kin = one(c, "character_goblin_king"), one(c, "character_goblin_cutter")
            openTurn(c, king)
            assert(Combat.useItem(c, king, itemNamed(king.char, "ability_rigged_hall"), 5, 6), "a lever is pulled")
            assert(Combat.resolveChannel(c, king), "and the row opens")
            assert(not onRow.alive or hp(onRow) <= 0, "the body on the row is downed")
            assert(not kin.alive or hp(kin) <= 0, "and so is his own goblin")
            assert(clear.alive and hp(clear) > 0, "the one off the row is not")
        end,
    },
}
