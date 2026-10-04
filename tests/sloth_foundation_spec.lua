-- Tests for SLOTH'S FOUNDATION (2026-10-04, "Sloth's Bestiary", five rounds): the rules more than one of the
-- circle's lines stand on.
--
--   the troll race   Indifferent -- never dodges; regrows a fifth of its health each turn unless fire or acid
--                    reached it since its last
--   Dormant          asleep with no countdown, takes no turns; a blow wakes it into Rude Awakening
--   Banked           turns put by, held to each keeper's own cap, knocked out one at a time, spent all at once
--   Drowsy           at 3 stacks the body falls Asleep
--
-- The bodies that wear these are pinned in their own line specs.

local Combat = require("models.combat")
local Race = require("models.race")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Bank = require("models.bank")
local Fixture = require("tests.support.fixture")

local unit = Fixture.unit

local function board() return Fixture.new(9, 9) end

-- A body on the enemy side wearing `items`, and a plain foe beside it.
local function field(items)
    local e = unit("character_archer", 4, 4, { isolate = "bare", items = items, stats = { health = 100 } })
    local f = unit("character_archer", 4, 5, { isolate = "bare", stats = { health = 100 } })
    local c = Fixture.combat(board(), f, { e })
    local mine, theirs
    for _, u in ipairs(c.units) do if u.side == "enemy" then mine = u else theirs = u end end
    return c, mine, theirs
end

local function wound(c, u, n, tags, from)
    Combat.dealFlatDamage(c, u, n, tags or { "physical" }, "test", from, { raw = true })
end

return {
    {
        name = "the troll is an unplayable humanoid race whose physical three sum to zero and whose organ is Indifferent",
        fn = function()
            local def = Race.defs["troll"]
            assert(def and def.kind == "humanoid", "a troll is a humanoid race")
            assert(def.playable == false, "the trolls are traffic, never the company's")
            local r = def.resist
            assert(r.slash + r.pierce + r.impact == 0, "the physical three sum to zero")
            assert(r.fire < 0, "fire is the rule's own answer")
            local grant = Item.defs["utility_troll_blood"]
            assert(grant and grant.bound and grant.noSteal, "Indifferent is an organ, not kit")
        end,
    },
    {
        name = "a troll never dodges",
        fn = function()
            local _, troll = field({ "utility_troll_blood" })
            assert(Status.has(troll, "status_indifferent"), "the fight opens with the badge on")
            assert(Status.statBonus(troll, "avoid") <= -100, "avoid -100: every blow that rolls lands")
        end,
    },
    {
        name = "a troll regrows a fifth of its health at the top of its turn",
        fn = function()
            local c, troll, foe = field({ "utility_troll_blood" })
            local max = Combat.unreservedMax(troll.char, "health")
            wound(c, troll, 40, nil, foe)
            local before = Fixture.hp(troll)
            Trait.onAnyTurnStart(c, troll)
            assert(Fixture.hp(troll) == math.min(max, before + math.floor(max * 0.2)),
                "a fifth of its health comes back")
        end,
    },
    {
        name = "fire or acid since its last turn stops the regrowth for one turn",
        fn = function()
            local c, troll, foe = field({ "utility_troll_blood" })
            wound(c, troll, 30, { "fire" }, foe)
            local before = Fixture.hp(troll)
            Trait.onAnyTurnStart(c, troll)
            assert(Fixture.hp(troll) == before, "burned: nothing regrows this turn")
            Trait.onAnyTurnStart(c, troll)
            assert(Fixture.hp(troll) > before, "and the mark is gone by the next")
            local c2, troll2, foe2 = field({ "utility_troll_blood" })
            wound(c2, troll2, 30, { "acid" }, foe2)
            local hp = Fixture.hp(troll2)
            Trait.onAnyTurnStart(c2, troll2)
            assert(Fixture.hp(troll2) == hp, "acid answers it the same way")
        end,
    },
    {
        name = "a Dormant body takes no turn, cannot move, and a blow wakes it into Rude Awakening",
        fn = function()
            local c, sleeper, foe = field({})
            Status.apply(c, sleeper, "status_dormant", { applier = sleeper })
            local def = Status.get(sleeper, "status_dormant").def
            assert(def.disablesActions and def.blocksMove, "it takes no turns while it sleeps")
            assert(Status.disablesReactions(sleeper), "and it answers nothing")
            Status.onDamaged(c, sleeper, 5, { "physical" })
            assert(not Status.has(sleeper, "status_dormant"), "the blow wakes it")
            assert(Status.has(sleeper, "status_rude_awakening"), "and it wakes worse")
            assert(Status.statBonus(sleeper, "damage") == 4 and Status.statBonus(sleeper, "speed") == 2,
                "+4 damage and +2 speed")
            Status.onTurnEnd(c, sleeper)
            assert(not Status.has(sleeper, "status_rude_awakening"), "until the end of its next turn")
        end,
    },
    {
        name = "a bank holds to its keeper's cap, is knocked out one turn at a time, and is spent whole",
        fn = function()
            local c, sloth = field({})
            assert(Bank.add(c, sloth, 1, 3) == 1)
            Bank.add(c, sloth, 1, 3); Bank.add(c, sloth, 1, 3)
            assert(Bank.add(c, sloth, 1, 3) == 3, "never past the keeper's cap")
            assert(Bank.knock(c, sloth) == 2, "a jolt knocks one turn out")
            assert(Bank.spend(c, sloth) == 2, "spending takes the whole bank")
            assert(Bank.count(sloth) == 0 and not Status.has(sloth, "status_banked"), "and the badge goes with it")
            assert(Bank.add(c, sloth, 12) == 12, "a keeper with no cap banks without limit")
        end,
    },
    {
        name = "at 3 Drowsy a body falls Asleep",
        fn = function()
            local c, _, body = field({})
            Status.apply(c, body, "status_drowsy", {})
            Status.apply(c, body, "status_drowsy", {})
            assert(Status.stacksOf(body, "status_drowsy") == 2 and not Status.has(body, "status_sleep"),
                "two stacks: still awake")
            Status.apply(c, body, "status_drowsy", {})
            assert(not Status.has(body, "status_drowsy"), "the third spends the stack")
            assert(Status.has(body, "status_sleep"), "and it falls Asleep")
        end,
    },
}
