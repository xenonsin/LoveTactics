-- Tests for THE CROWN'S DEMONIC CREATURES AND ITS DEATH KNIGHT ("The Crown's Bestiary", slice B, approved
-- 2026-10-09): five bodies on the floor under every circle.
--
--   Pit Imp       The Offer: its sting lays Blood Debt -- +5 damage for 2 turns, then a third of what was dealt
--   Chain Fiend   Drag Below: a hooked chain at 3 pulls the struck body in and Roots it for 1 turn
--   Erinys        Fit the Crime: her arrow answers the target's last turn (Disarmed/Silenced/Root/Interred)
--   Balor         Hellfire Ring (a telegraphed ring of 2) and Death Throes (a blast of 3, its own side included)
--   Death Knight  Bulwark of the Fallen: an ally falling within 3 becomes a Physical Barrier of half its health
--
-- Each case pins a rule the review approved, on a bare board, plus the drops (which run the same rules for the
-- company) and the two fights.

local Character = require("models.character")
local Combat = require("models.combat")
local Crown = require("models.crown_demons")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

local unit, itemNamed, hp = Fixture.unit, Fixture.itemNamed, Fixture.hp

local BODIES = {
    character_pit_imp = { tier = 1, carries = "weapon_the_offer", drop = "ability_signed_in_blood", class = "warlord" },
    character_chain_fiend = { tier = 2, carries = "weapon_drag_below", drop = "ability_hook_and_drag", class = "trapper" },
    character_erinys = { tier = 3, carries = "weapon_fit_the_crime", drop = "ability_furys_verdict", class = "inquisitor" },
    character_balor = { tier = 4, carries = "utility_balor_throes", drop = "utility_last_breath", class = "bombardier" },
    character_death_knight = { tier = 3, carries = "utility_bulwark_of_the_fallen", drop = "armor_oathbound_plate",
        class = "sentinel" },
}

local function board(tiles) return Fixture.new(12, 12, { tiles = tiles }) end

local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 100, health or 100
    return spawn
end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function hit(c, target, amount, attacker, tags)
    return Combat.dealFlatDamage(c, target, amount, tags or { "physical" }, "test", attacker, { raw = true })
end

local function kill(c, u) return Combat.dealFlatDamage(c, u, 9999, { "physical" }, "test", nil, { raw = true }) end

-- Run the clock past a status, as a turn would.
local function runOut(c, u, id)
    local s = Status.get(u, id)
    Status.tick(c, (s and s.remaining or 0) + 1)
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "five bodies, each with its rule on its own grid and its trophy on a real shelf",
        fn = function()
            for id, want in pairs(BODIES) do
                local def = Character.defs[id]
                assert(def, id .. " exists")
                assert(def.tier == want.tier, id .. " stands on tier " .. want.tier)
                local c = Character.instantiate(id)
                assert(itemNamed(c, want.carries), id .. " carries " .. want.carries)
                assert(def.drops and def.drops[1] == want.drop, id .. " drops " .. want.drop)
                local drop = Item.defs[want.drop]
                assert(drop.class == want.class, want.drop .. " is " .. want.class .. " stock")
                assert(drop.unstocked and not drop.price, want.drop .. " is a trophy: on the rack, never sold")
                local own = Item.defs[want.carries]
                assert(own.class == "creature" and own.noSteal, want.carries .. " is a body's own")
            end
            -- The four creatures are demons, each its own species, and every blow they throw burns.
            for _, id in ipairs({ "character_pit_imp", "character_chain_fiend", "character_erinys", "character_balor" }) do
                assert(Character.defs[id].race == "demon", id .. " is a demon")
            end
            for _, id in ipairs({ "weapon_the_offer", "weapon_drag_below", "weapon_fit_the_crime", "weapon_flame_lash" }) do
                local tags = {}
                for _, t in ipairs(Item.defs[id].tags) do tags[t] = true end
                assert(tags.fire and tags.physical, id .. " burns, as a physical blow")
            end
            -- The Erinys flies; the Balor is 2x2 and an elite.
            assert(itemNamed(Character.instantiate("character_erinys"), "utility_manticore_wings"), "the Erinys flies")
            local balor = Character.defs.character_balor
            assert(balor.footprint and balor.footprint.w == 2 and balor.footprint.h == 2, "the Balor is 2x2")
            -- The Death Knight is built as the dead are: the human race, the knight's class, undead on top.
            local dk = Character.defs.character_death_knight
            assert(dk.race == "human" and dk.class == "knight" and dk.undead, "a knight, still human, and dead")
            assert(Character.isUndead(Character.instantiate("character_death_knight")), "Character.isUndead says so")
            local n = 0
            for _, it in ipairs(Character.eachItem(Character.instantiate("character_death_knight"))) do
                if it then n = n + 1 end
            end
            assert(n >= 3, "a tier-3 humanoid carries at least three items")
        end,
    },
    {
        name = "the Tribunal and the Balor stand on the Crown's floor, with no rung",
        fn = function()
            local tribunal = Encounter.get("encounter_crown_the_tribunal")
            assert(tribunal and tribunal.kind == "combat" and tribunal.weight == 3, "the Tribunal is traffic at weight 3")
            local balor = Encounter.get("encounter_crown_the_balor")
            assert(balor and balor.kind == "elite", "the Balor is an elite")
            for _, e in ipairs({ tribunal, balor }) do
                assert(e.rung == nil, e.name .. " carries no rung: the ground is the pin")
                assert(e.condition({ biome = "underworld" }) and not e.condition({ biome = "desert" }),
                    e.name .. " is underworld-locked")
            end
            local function same(got, want)
                table.sort(got); table.sort(want)
                if #got ~= #want then return false end
                for i = 1, #got do if got[i] ~= want[i] then return false end end
                return true
            end
            local function copy(t) local o = {} for i, v in ipairs(t) do o[i] = v end return o end
            assert(same(copy(tribunal.composition),
                { "character_death_knight", "character_erinys", "character_pit_imp" }), "three bodies, fixed")
            assert(same(copy(balor.composition),
                { "character_balor", "character_chain_fiend", "character_pit_imp", "character_pit_imp" }),
                "the Balor, a Chain Fiend and two Pit Imps")
        end,
    },
    -- ------------------------------------------------------------------------------ The Offer
    {
        name = "The Offer: the sting lays Blood Debt, +5 damage, and a third of what was dealt comes due",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 6), { unit("character_pit_imp", 5, 5), walker(8, 8, 200) })
            local body, imp, dummy = c.units[1], one(c, "character_pit_imp"), c.units[3]
            local damageBefore = Combat.flatStat(body, "damage")
            Fixture.strike(c, imp, body, "weapon_the_offer")
            assert(Status.has(body, "status_blood_debt"), "the sting lays Blood Debt")
            assert(Combat.flatStat(body, "damage") == damageBefore + 5, "+5 damage")
            hit(c, dummy, 20, body)
            hit(c, dummy, 10, body)
            assert(Status.get(body, "status_blood_debt").dealt == 30, "the ledger runs up what it deals")
            local before = hp(body)
            runOut(c, body, "status_blood_debt")
            assert(not Status.has(body, "status_blood_debt"), "the debt has run out")
            assert(hp(body) == before - 10, "a third of 30 comes due")
        end,
    },
    {
        name = "The Offer: a debt Cured off before it comes due is never paid; Blood Debt is not Owed",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 6), { walker(8, 8, 200) })
            local body, dummy = c.units[1], c.units[2]
            Status.apply(c, body, "status_blood_debt")
            hit(c, dummy, 30, body)
            local before = hp(body)
            Combat.cleanse(c, body)
            assert(not Status.has(body, "status_blood_debt") and hp(body) == before, "Cured, nothing is charged")
            local debt, owed = Status.defs.status_blood_debt, Status.defs.status_owed
            assert(debt.name == "Blood Debt" and debt.debuff, "a debuff named Blood Debt")
            assert(debt.description ~= owed.description and not debt.vulnerable,
                "it reads apart from Owed, and adds nothing to the blows it takes")
        end,
    },
    -- ------------------------------------------------------------------------------ Drag Below
    {
        name = "Drag Below: the chain at 3 pulls the struck body beside the fiend and Roots it for a turn",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 6), { unit("character_chain_fiend", 5, 3) })
            local body, fiend = c.units[1], one(c, "character_chain_fiend")
            local ok = Fixture.strike(c, fiend, body, "weapon_drag_below")
            assert(ok, "the chain reaches 3")
            assert(Combat.unitGap(fiend, body) == 1, "pulled in beside the fiend")
            local root = Status.get(body, "status_root")
            assert(root and root.remaining == Status.TICKS_PER_TURN, "Rooted there for 1 turn")
        end,
    },
    {
        name = "Drag Below: a pull stops on a body in the line",
        fn = function()
            local c = Fixture.combat(board(), { walker(5, 6), walker(5, 4) }, { unit("character_chain_fiend", 5, 2) })
            local far, near, fiend = c.units[1], c.units[2], one(c, "character_chain_fiend")
            -- The far body is 4 off, so hook it from 3 by hand through the same rule the chain uses.
            fiend.y = 3
            Fixture.openTurn(c, fiend)
            Crown.dragBelow({ pull = function(t) return Combat.pull(c, fiend, t) end,
                applyStatus = function(t, id, o) return Status.apply(c, t, id, o) end }, far)
            assert(far.y == 5 and Combat.unitGap(fiend, far) > 1, "the ally in the line stops the haul")
        end,
    },
    -- ------------------------------------------------------------------------------ Fit the Crime
    {
        name = "Fit the Crime: attacked is Disarmed, cast is Silenced, moved is Root, healed is Interred",
        fn = function()
            local cases = {
                { deed = "attacked", want = "status_disarmed" },
                { deed = "cast", want = "status_silenced" },
                { deed = "moved", want = "status_root" },
                { deed = "healed", want = "status_interred" },
            }
            for _, k in ipairs(cases) do
                -- A dummy foe beside the body, so a sword and a bolt both have something in reach.
                local c = Fixture.combat(board(), { walker(5, 8, 300), walker(6, 9) },
                    { unit("character_erinys", 5, 3), walker(4, 8, 300) })
                local body, other, fury, dummy = c.units[1], c.units[2], one(c, "character_erinys"), c.units[4]
                body.char.stats.mana.max, body.char.stats.mana.current = 50, 50
                Fixture.openTurn(c, body)
                if k.deed == "attacked" then
                    Fixture.strike(c, body, dummy, Item.instantiate("weapon_iron_sword"))
                elseif k.deed == "cast" then
                    Fixture.strike(c, body, dummy, Item.instantiate("ability_fire_bolt"))
                elseif k.deed == "moved" then
                    assert(Combat.moveUnit(c, body, 5, 7), "it walks")
                else
                    other.char.stats.health.current = 50
                    body.char.stats.mana.max, body.char.stats.mana.current = 50, 50
                    Fixture.strike(c, body, other, Item.instantiate("ability_heal"))
                end
                assert(Crown.lastDeeds(body)[k.deed], k.deed .. " is noted as a deed of its turn")
                Fixture.strike(c, fury, body, "weapon_fit_the_crime")
                assert(Status.has(body, k.want), k.deed .. " is answered with " .. k.want)
            end
        end,
    },
    {
        name = "Fit the Crime: a body that did nothing on its last turn takes only the arrow",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 8, 300), { unit("character_erinys", 5, 3) })
            local body, fury = c.units[1], one(c, "character_erinys")
            Fixture.openTurn(c, body)
            assert(Combat.moveUnit(c, body, 5, 7), "it walks")
            -- A later turn in which it does nothing: the walk was a turn ago.
            Combat.tally(body, "turnTaken", 1)
            local before = hp(body)
            Fixture.strike(c, fury, body, "weapon_fit_the_crime")
            assert(hp(body) < before, "the arrow lands")
            for _, id in ipairs({ "status_disarmed", "status_silenced", "status_root", "status_interred" }) do
                assert(not Status.has(body, id), "and no sentence: " .. id)
            end
        end,
    },
    -- ------------------------------------------------------------------------------ the Balor
    {
        name = "Hellfire Ring: a telegraphed wind-up that burns every tile within 2 of the whole body",
        fn = function()
            local c = Fixture.combat(board(), { walker(4, 5), walker(8, 6), walker(5, 9) },
                { unit("character_balor", 5, 5) })
            local west, east, clear, balor = c.units[1], c.units[2], c.units[3], one(c, "character_balor")
            local ring = Item.defs.ability_hellfire_ring.activeAbility
            assert(ring.windup and ring.windup > 0 and ring.range == 0, "a self-cast with a wind-up")
            local cells = Combat.aoeCells(c, ring, balor.x, balor.y, balor)
            local depth = {}
            for _, cell in ipairs(cells) do
                local g = Combat.cellGap(cell.x, cell.y, balor)
                assert(g >= 1 and g <= 2, "every telegraphed cell lies within 2 of the body")
                depth[g] = true
            end
            assert(depth[1] and depth[2], "both depths of the ring are drawn")
            local before = { hp(west), hp(east), hp(clear) }
            balor.char.stats.stamina.current = 99
            Fixture.openTurn(c, balor)
            assert(Combat.useItem(c, balor, itemNamed(balor.char, "ability_hellfire_ring"), balor.x, balor.y),
                "it winds up")
            assert(hp(west) == before[1] and hp(east) == before[2], "nothing burns until the wind-up resolves")
            Combat.resolveChannel(c, balor)
            assert(hp(west) < before[1], "a body beside it burns")
            assert(hp(east) < before[2], "a body 2 from its far side burns")
            assert(hp(clear) == before[3], "a body 3 off has stepped out of the ring")
        end,
    },
    {
        name = "Death Throes: the Balor explodes as it dies, within 3, its own escort included",
        fn = function()
            local c = Fixture.combat(board(), { walker(4, 5), walker(5, 10) },
                { unit("character_balor", 5, 5), unit("character_pit_imp", 9, 5) })
            local near, far, balor, imp = c.units[1], c.units[2], one(c, "character_balor"), one(c, "character_pit_imp")
            imp.char.stats.health.max, imp.char.stats.health.current = 200, 200
            local before = { hp(near), hp(far), hp(imp) }
            kill(c, balor)
            assert(not balor.alive, "the Balor is down")
            assert(hp(near) < before[1], "a foe beside it takes the blast")
            assert(hp(imp) < before[3], "and so does its own escort, 3 off")
            assert(hp(far) == before[2], "4 off is clear: finish it from range")
        end,
    },
    -- ------------------------------------------------------------------------------ Bulwark of the Fallen
    {
        name = "Bulwark of the Fallen: an ally falling within 3 closes over the knight as half its max health",
        fn = function()
            local c = Fixture.combat(board(), walker(1, 1),
                { unit("character_death_knight", 5, 5), unit("character_chain_fiend", 5, 7),
                  unit("character_pit_imp", 10, 10) })
            local body, dk = c.units[1], one(c, "character_death_knight")
            local fiend, imp = one(c, "character_chain_fiend"), one(c, "character_pit_imp")
            kill(c, imp)
            assert(not Status.has(dk, "status_physical_barrier"), "an ally falling 10 off closes over nothing")
            kill(c, fiend)
            local bar = Status.get(dk, "status_physical_barrier")
            assert(bar and bar.def.name == "Physical Barrier", "a Physical Barrier closes over the knight")
            assert(bar.pool == math.floor(fiend.char.stats.health.max / 2), "worth half the fallen ally's max health")
            local before, pool = hp(dk), bar.pool
            hit(c, dk, 10, body)
            assert(hp(dk) == before and bar.pool == pool - 10, "a physical blow is paid out of the barrier")
            hit(c, dk, 10, body, { "magical", "fire" })
            assert(hp(dk) < before and bar.pool == pool - 10, "magic goes straight past it")
            hit(c, dk, 999, body)
            assert(not Status.has(dk, "status_physical_barrier"), "the barrier goes once it is spent")
        end,
    },
    -- ------------------------------------------------------------------------------ the trophies
    {
        name = "the trophies: Signed in Blood, Hook and Drag, Fury's Verdict, Last Breath and Oathbound Plate",
        fn = function()
            -- Signed in Blood lays the same debt on an ally.
            local c = Fixture.combat(board(),
                { unit("character_archer", 5, 8, { isolate = "bare", items = { "ability_signed_in_blood" } }), walker(6, 8) },
                { walker(5, 2) })
            local warlord, ally = c.units[1], c.units[2]
            Fixture.strike(c, warlord, ally, "ability_signed_in_blood")
            assert(Status.has(ally, "status_blood_debt"), "Signed in Blood puts Blood Debt on an ally")

            -- Hook and Drag pulls a foe from 3 and Roots it.
            local c2 = Fixture.combat(board(),
                unit("character_archer", 5, 8, { isolate = "bare", items = { "ability_hook_and_drag" } }),
                { walker(5, 5) })
            local trapper, foe = c2.units[1], c2.units[2]
            assert(Fixture.strike(c2, trapper, foe, "ability_hook_and_drag"), "it hooks from 3")
            assert(Combat.unitGap(trapper, foe) == 1 and Status.has(foe, "status_root"), "pulled in and Rooted")

            -- Fury's Verdict answers three crimes and not a heal.
            local c3 = Fixture.combat(board(),
                unit("character_archer", 5, 8, { isolate = "bare", items = { "ability_furys_verdict" },
                    stats = { mana = 50 } }),
                { walker(5, 4, 300), walker(6, 4) })
            local inq, target = c3.units[1], c3.units[2]
            Fixture.openTurn(c3, target)
            Crown.noteDeed(c3, target, "healed")
            Fixture.strike(c3, inq, target, "ability_furys_verdict")
            assert(not Status.has(target, "status_interred"), "a heal goes unanswered: Interred stays the Fury's")
            Combat.tally(target, "turnTaken", 1)
            Fixture.openTurn(c3, target)
            assert(Combat.moveUnit(c3, target, 4, 4), "it walks")
            inq.cooldowns = {} -- the second shot is not what is on trial
            Fixture.strike(c3, inq, target, "ability_furys_verdict")
            assert(Status.has(target, "status_root"), "a walk is answered with Root")

            -- Last Breath bursts within 2 when its bearer falls.
            local c4 = Fixture.combat(board(),
                unit("character_archer", 5, 5, { isolate = "bare", items = { "utility_last_breath" } }),
                { walker(5, 7), walker(5, 9) })
            local bomb, near, far = c4.units[1], c4.units[2], c4.units[3]
            local nb, fb = hp(near), hp(far)
            kill(c4, bomb)
            assert(hp(near) < nb and hp(far) == fb, "fire within 2, nothing at 4")

            -- Oathbound Plate closes a quarter of a fallen ally over its bearer.
            local c5 = Fixture.combat(board(),
                { unit("character_archer", 5, 5, { isolate = "bare", items = { "armor_oathbound_plate" } }),
                  walker(5, 7, 100) },
                { walker(1, 1) })
            local sentinel, fallen = c5.units[1], c5.units[2]
            kill(c5, fallen)
            local bar = Status.get(sentinel, "status_physical_barrier")
            assert(bar and bar.pool == 25, "a quarter of the fallen ally's 100")
        end,
    },
}
