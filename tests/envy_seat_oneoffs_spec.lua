-- Tests for ENVY'S SEAT, THE ONE-OFF FAMILIES (slice C of "Envy's Bestiary", reviewed 2026-10-01..03): five bodies on
-- the Ribstone Waste's second floor, each its own family, their rules, their drops and their fights.
--
--   the Homunculus     3 Red Stone; a killing blow consumes one and it stands back up whole next turn; heals 10% a
--                      turn while it holds any; Unclosing stops both. Drops the Stone Heart (apothecary)
--   the Brazen Head    Time is / Time was / Time is past, each a wind-up a shove breaks, in order. Drops Time Was
--                      (theurge) and Time Is Past (artificer)
--   the Echo           a foe's cast within 3 is repeated at half power at the caster. Drops the Echoing Shell
--                      (spellbreaker)
--   Arachne            at 3 threads of one ability she casts it back, once. Drops the Weaver's Shuttle (theurge)
--   the Penitents      strike the last of the company to act; Invisible and Blind mean nothing. Drop Iron Thread
--                      (inquisitor)
-- Each case pins a rule the review approved, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local AI = require("models.ai")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local BODIES = {
    character_red_homunculus = { race = "construct", tier = 3, drops = { "utility_stone_heart" } },
    character_brazen_head = { race = "construct", tier = 3, drops = { "ability_time_was", "utility_time_is_past" } },
    character_echo = { race = "elemental", tier = 2, drops = { "utility_echoing_shell" } },
    character_arachne = { race = "beast", tier = 3, drops = { "utility_weavers_shuttle" } },
    character_sewn_eyed_penitent = { race = "undead", tier = 2, drops = { "utility_iron_thread" } },
}
local DROPS = {
    utility_stone_heart = "apothecary", ability_time_was = "theurge", utility_time_is_past = "artificer",
    utility_echoing_shell = "spellbreaker", utility_weavers_shuttle = "theurge", utility_iron_thread = "inquisitor",
}
local ORGANS = {
    "utility_red_stone_heart", "utility_brazen_voice", "utility_only_repeats", "utility_the_tapestry",
    "utility_sewn_eyes", "ability_time_is_spoken", "ability_time_was_spoken", "ability_time_is_past_spoken",
    "weapon_borrowed_voice", "weapon_spinnerets", "weapon_penitents_scourge",
}
local FIGHTS = {
    encounter_envy_the_brazen_head = "elite", encounter_envy_the_penitents = "combat",
    encounter_envy_arachnes_loom = "combat", encounter_envy_the_red_stone = "combat",
}

local function board(n) return Fixture.new(n or 11, n or 11) end

-- A sturdy company body: an archer with its grid emptied, given `items`, and room to take blows.
local function body(x, y, items, stats)
    stats = stats or {}
    stats.health = stats.health or 300
    stats.mana = stats.mana or 100
    return unit("character_archer", x, y, { isolate = "bare", items = items or { "weapon_iron_bow" }, stats = stats })
end

-- A sturdy enemy-side body of no consequence, for something to aim at.
local function dummy(x, y, items)
    return unit("character_glass_eater", x, y, { isolate = "bare", items = items or { "weapon_vitreous_bite" },
        stats = { health = 300, mana = 100 } })
end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function maxHp(u) return Combat.unreservedMax(u.char, "health") end

local function cast(c, caster, id, target)
    caster.char.stats.mana.current = 100
    openTurn(c, caster)
    return Combat.useItem(c, caster, itemNamed(caster.char, id), target.x, target.y)
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "five one-off families, none of them human, each dropping its own piece on a real shelf",
        fn = function()
            for id, want in pairs(BODIES) do
                local def = Character.defs[id]
                assert(def, id .. " exists")
                assert(def.race == want.race and def.race ~= "human", id .. " is a " .. want.race)
                assert(def.tier == want.tier, id .. " is tier " .. want.tier)
                assert(#def.drops == #want.drops, id .. " drops what the page gave it")
                for i, d in ipairs(want.drops) do assert(def.drops[i] == d, id .. " drops " .. d) end
            end
            assert(Character.defs["character_homunculus"].tier == 1,
                "the alchemist's summon keeps its own id and body")
            for id, class in pairs(DROPS) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.class == class, id .. " sits on the " .. class .. " shelf")
                assert(def.unstocked and def.unlockLevel == 12, id .. " is an unstocked trophy on the seat's rung")
            end
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal, id .. " is a body's own")
            end
            assert(Item.defs["utility_stone_heart"].description:find("Red Stone"),
                "the Stone Heart stores Red Stone, the count's own name")
            assert(Status.defs["status_red_stone"].name == "Red Stone", "Red Stone is not Medusa's Stone")
        end,
    },
    {
        name = "four fights on the waste's seat: the Brazen Head's elite and three ordinary ones",
        fn = function()
            local sets = {}
            for id, kind in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e, id .. " exists")
                assert(e.kind == kind, id .. " is " .. kind)
                assert(e.rung == 2, id .. " stands on the seat")
                assert(e.condition({ biome = "desert" }) and not e.condition({ biome = "volcanic" }),
                    id .. " is locked to the waste")
                if kind == "combat" then assert(e.weight >= 2 and e.weight <= 5, id .. " weighs 2-5") end
                local seen = {}
                for _, c in ipairs(e.composition({ depth = 12, rung = 2, biome = "desert" })) do
                    assert(Character.defs[c], id .. " fields a real body: " .. c)
                    seen[c] = true
                end
                local key = {}
                for c in pairs(seen) do key[#key + 1] = c end
                table.sort(key)
                key = table.concat(key, ",")
                assert(not sets[key], id .. " fields the same bodies as " .. tostring(sets[key]))
                sets[key] = id
            end
            local head = Encounter.get("encounter_envy_the_brazen_head").composition({})
            local n = 0
            for _, c in ipairs(head) do if c == "character_red_homunculus" then n = n + 1 end end
            assert(head[1] == "character_brazen_head" and n == 2, "the head fights behind two Homunculi")
        end,
    },
    -- ------------------------------------------------------------------------------ the Homunculus
    {
        name = "the Homunculus: a killing blow consumes a Red Stone, and it stands back up whole next turn",
        fn = function()
            local c = Fixture.combat(board(), body(5, 7), { unit("character_red_homunculus", 5, 5) })
            local foe, h = c.units[1], one(c, "character_red_homunculus")
            assert(Status.stacksOf(h, "status_red_stone") == 3, "it opens with 3 Red Stone")
            Combat.dealFlatDamage(c, h, 9999, { "physical" }, "test", foe, { raw = true })
            assert(h.alive and hp(h) == 1, "the killing blow is caught")
            assert(Status.stacksOf(h, "status_red_stone") == 2, "and a stone is consumed")
            Trait.onAnyTurnStart(c, h)
            assert(hp(h) == maxHp(h), "at the top of its turn it stands back up at full health")
            -- a fallen one is ended by blows in the same round, one stone each
            for _ = 1, 2 do Combat.dealFlatDamage(c, h, 9999, { "physical" }, "test", foe, { raw = true }) end
            assert(h.alive and Status.stacksOf(h, "status_red_stone") == 0, "every blow consumes one")
            Combat.dealFlatDamage(c, h, 9999, { "physical" }, "test", foe, { raw = true })
            assert(not h.alive, "at 0 it dies for good")
        end,
    },
    {
        name = "the Homunculus heals a tenth a turn while it holds a stone, and Unclosing stops both",
        fn = function()
            local c = Fixture.combat(board(), body(5, 7), { unit("character_red_homunculus", 5, 5) })
            local foe, h = c.units[1], one(c, "character_red_homunculus")
            Combat.dealFlatDamage(c, h, 40, { "physical" }, "test", foe, { raw = true })
            local before = hp(h)
            Trait.onAnyTurnStart(c, h)
            assert(hp(h) == before + math.floor(maxHp(h) * 0.1 + 0.5), "it heals 10% of its health")

            Status.apply(c, h, "status_unclosing_wound", { duration = 99 })
            before = hp(h)
            Trait.onAnyTurnStart(c, h)
            assert(hp(h) == before, "Unclosing: no healing")
            Combat.dealFlatDamage(c, h, 9999, { "physical" }, "test", foe, { raw = true })
            assert(not h.alive, "and no getting up: the stones it still held do not catch the blow")
        end,
    },
    -- ------------------------------------------------------------------------------ the Brazen Head
    {
        name = "the Brazen Head speaks in order, each utterance a wind-up a shove breaks",
        fn = function()
            local c = Fixture.combat(board(), { body(5, 6), body(5, 8), body(1, 1) },
                { unit("character_brazen_head", 5, 5), unit("character_red_homunculus", 8, 2) })
            local shover, near, far = c.units[1], c.units[2], c.units[3]
            local head, h = one(c, "character_brazen_head"), one(c, "character_red_homunculus")
            local timeIs = itemNamed(head.char, "ability_time_is_spoken")
            assert(Combat.itemBlockReason(head, itemNamed(head.char, "ability_time_was_spoken")),
                "Time Was waits its turn")
            openTurn(c, head)
            local plan = AI.plan(c, head)
            assert(plan and plan.reason == "the head speaks" and plan.item == timeIs, "it opens with Time Is")

            assert(Combat.useItem(c, head, timeIs, head.x, head.y), "it begins Time Is")
            assert(head.channel, "a wind-up")
            Combat.knockback(c, shover, head, 1)
            assert(not head.channel and (head.utterances or 0) == 0, "a shove breaks it, and nothing was said")

            openTurn(c, head)
            assert(Combat.useItem(c, head, timeIs, head.x, head.y), "so it says it again")
            Combat.resolveChannel(c, head)
            assert(Status.has(h, "status_hasted") and Status.has(head, "status_hasted"), "Time is: its side is Hasted")
            assert(head.utterances == 1, "one utterance spoken")

            Combat.dealFlatDamage(c, h, 30, { "physical" }, "test", shover, { raw = true })
            local wounded = hp(h)
            openTurn(c, head)
            assert(Combat.useItem(c, head, itemNamed(head.char, "ability_time_was_spoken"), head.x, head.y))
            Combat.resolveChannel(c, head)
            assert(hp(h) == wounded + 30, "Time was: it heals what it lost since the last utterance")

            near.x, near.y = head.x, head.y + 3
            openTurn(c, head)
            assert(Combat.useItem(c, head, itemNamed(head.char, "ability_time_is_past_spoken"), head.x, head.y))
            Combat.resolveChannel(c, head)
            assert(not head.alive, "Time is past: the head shatters")
            assert(Status.has(near, "status_stun"), "and a foe within 3 is Stunned")
            assert(not Status.has(far, "status_stun"), "but not one beyond it")
        end,
    },
    -- ------------------------------------------------------------------------------ the Echo
    {
        name = "the Echo repeats a foe's cast within 3 at half power, at the caster",
        fn = function()
            local c = Fixture.combat(board(), { body(5, 7, { "ability_fire_bolt" }), body(5, 1, { "ability_fire_bolt" }) },
                { unit("character_echo", 5, 5), dummy(7, 7), dummy(7, 1) })
            local near, far = c.units[1], c.units[2]
            local target, target2 = c.units[4], c.units[5]
            local before = hp(near)
            assert(cast(c, near, "ability_fire_bolt", target), "a bolt is cast beside the Echo")
            assert(hp(near) < before, "and it comes back at the caster")
            before = hp(far)
            assert(cast(c, far, "ability_fire_bolt", target2), "a bolt cast four tiles off")
            assert(hp(far) == before, "is out of her hearing")
            local seat = require("models.envy_seat")
            assert(not seat.repeatable(Item.instantiate("ability_heal")), "a heal has no blow to repeat")
        end,
    },
    -- ------------------------------------------------------------------------------ Arachne
    {
        name = "Arachne weaves each cast in her sight, and at the third thread casts it back once",
        fn = function()
            local c = Fixture.combat(board(), body(5, 8, { "ability_fire_bolt" }),
                { unit("character_arachne", 5, 2), dummy(6, 9) })
            local caster, a, target = c.units[1], one(c, "character_arachne"), c.units[3]
            for i = 1, 2 do
                local before = hp(caster)
                assert(cast(c, caster, "ability_fire_bolt", target))
                assert(hp(caster) == before, "thread " .. i .. " is only woven")
            end
            assert(Status.stacksOf(a, "status_woven") == 2, "two threads on the tapestry")
            local before = hp(caster)
            assert(cast(c, caster, "ability_fire_bolt", target))
            assert(hp(caster) < before, "the third thread: she casts it back")
            before = hp(caster)
            assert(cast(c, caster, "ability_fire_bolt", target))
            assert(hp(caster) == before, "once")
        end,
    },
    -- ------------------------------------------------------------------------------ the Penitents
    {
        name = "the Penitents strike the last of the company to act, hidden or not, and cannot be Blinded",
        fn = function()
            local c = Fixture.combat(board(), { body(6, 5), body(5, 9) }, { unit("character_sewn_eyed_penitent", 5, 5) })
            local near, last = c.units[1], c.units[2]
            local p = one(c, "character_sewn_eyed_penitent")
            Trait.onAnyTurnEnd(c, near)
            Trait.onAnyTurnEnd(c, last)
            Status.apply(c, last, "status_invisible", {})
            assert(Status.untargetable(last, c), "the last to act is Invisible")
            openTurn(c, p)
            local plan = AI.plan(c, p)
            assert(plan and plan.reason == "hunts by ear", "the penitent hunts by ear")
            assert(plan.tx == last.x and plan.ty == last.y, "and strikes the last to act, past the nearer foe")
            Status.apply(c, p, "status_blind", {})
            assert(not Status.has(p, "status_blind"), "its eyes are already shut")
        end,
    },
    -- ------------------------------------------------------------------------------ the drops
    {
        name = "the Stone Heart banks a Red Stone off each kill, and a stone catches a killing blow at 1",
        fn = function()
            local c = Fixture.combat(board(), body(5, 6, { "weapon_iron_bow", "utility_stone_heart" }),
                { dummy(5, 5), dummy(8, 8) })
            local me, foe = c.units[1], c.units[2]
            Combat.dealFlatDamage(c, foe, 9999, { "physical" }, "test", me, { raw = true })
            assert(Status.stacksOf(me, "status_red_stone") == 1, "a kill stores a Red Stone")
            Combat.dealFlatDamage(c, me, 9999, { "physical" }, "test", c.units[3], { raw = true })
            assert(me.alive and hp(me) == 1, "a killing blow consumes it and leaves the bearer at 1")
            Combat.dealFlatDamage(c, me, 9999, { "physical" }, "test", c.units[3], { raw = true })
            assert(not me.alive, "with none stored, the blow lands")
        end,
    },
    {
        name = "Time Was returns an ally to the health it had at the start of your last turn",
        fn = function()
            local c = Fixture.combat(board(), { body(5, 6, { "ability_time_was" }), body(5, 8) }, { dummy(1, 1) })
            local me, ally = c.units[1], c.units[2]
            local full = hp(ally)
            Trait.onAnyTurnStart(c, me)
            Combat.dealFlatDamage(c, ally, 50, { "physical" }, "test", c.units[3], { raw = true })
            Trait.onAnyTurnStart(c, me)
            assert(cast(c, me, "ability_time_was", ally), "it is cast on an ally within 3")
            assert(hp(ally) == full, "and the ally stands where it stood at the start of your last turn")
        end,
    },
    {
        name = "Time Is Past: when the bearer falls, every foe within 3 is Stunned",
        fn = function()
            local c = Fixture.combat(board(), body(5, 5, { "weapon_iron_bow", "utility_time_is_past" }),
                { dummy(5, 8), dummy(5, 10) })
            local me, near, far = c.units[1], c.units[2], c.units[3]
            Combat.dealFlatDamage(c, me, 9999, { "physical" }, "test", near, { raw = true })
            assert(not me.alive, "the bearer falls")
            assert(Status.has(near, "status_stun") and not Status.has(far, "status_stun"), "within 3, Stunned")
        end,
    },
    {
        name = "the Echoing Shell: a foe's cast within 3 leaves the bearer Idle, and its next use lifts it",
        fn = function()
            local c = Fixture.combat(board(), body(5, 5, { "ability_fire_bolt", "utility_echoing_shell" }),
                { dummy(5, 7, { "ability_fire_bolt" }) })
            local me, foe = c.units[1], c.units[2]
            assert(cast(c, foe, "ability_fire_bolt", me), "a foe casts beside the bearer")
            assert(Status.has(me, "status_idle"), "the bearer is Idle")
            local mana = me.char.stats.mana.current
            openTurn(c, me)
            assert(Combat.useItem(c, me, itemNamed(me.char, "ability_fire_bolt"), foe.x, foe.y))
            assert(me.char.stats.mana.current == mana, "and its next cast costs nothing")
            assert(not Status.has(me, "status_idle"), "after which it is not Idle")
        end,
    },
    {
        name = "the Weaver's Shuttle: a foe's ability cast twice is the bearer's to cast once",
        fn = function()
            local c = Fixture.combat(board(), body(5, 5, { "weapon_iron_bow", "utility_weavers_shuttle" }),
                { dummy(5, 7, { "ability_fire_bolt" }) })
            local me, foe = c.units[1], c.units[2]
            assert(cast(c, foe, "ability_fire_bolt", me))
            assert(not itemNamed(me.char, "ability_fire_bolt"), "once is not a pattern")
            assert(cast(c, foe, "ability_fire_bolt", me))
            local lent = itemNamed(me.char, "ability_fire_bolt")
            assert(lent and lent.woven and lent.onLoan, "twice is: the bearer holds a copy on loan")
            assert(cast(c, me, "ability_fire_bolt", foe), "it is cast")
            assert(not itemNamed(me.char, "ability_fire_bolt"), "once")
        end,
    },
    {
        name = "Iron Thread: the bearer cannot be Blinded, and Invisible foes within 2 are Limned",
        fn = function()
            local c = Fixture.combat(board(), body(5, 5, { "weapon_iron_bow", "utility_iron_thread" }),
                { dummy(5, 7), dummy(5, 9) })
            local me, near, far = c.units[1], c.units[2], c.units[3]
            Status.apply(c, me, "status_blind", {})
            assert(not Status.has(me, "status_blind"), "no Blind")
            Status.apply(c, near, "status_invisible", {})
            Status.apply(c, far, "status_invisible", {})
            assert(not Status.untargetable(near, c), "an Invisible foe within 2 can be targeted")
            assert(Status.untargetable(far, c), "one farther off cannot")
        end,
    },
}
