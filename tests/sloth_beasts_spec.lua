-- Tests for SLOTH'S APPROACH BEASTS (2026-10-04, "Sloth's Bestiary", slice A): the Ground Sloth, the Old Sloth,
-- the Yeti and the Dread of the Whiteout, their rules, their three fights and their four trophies.
--
--   Banked               a sloth does nothing on a turn no foe is in reach and banks it (to 3); its next swing
--                        lands once per banked turn and once more; a blow that lands on it knocks one out
--   The Old Sloth        opens Dormant with a full bank of 5; spends the bank as ring sweeps of every foe beside it
--   Whiteout Roar        at a yeti's turn start, every foe within 4 with no ally beside it is Rooted
--   Whiteout             the Dread is Unseen to foes more than 2 tiles away; a Limn finds her
--   Drag Into the White  the Dread hauls a Rooted body 3 tiles toward her, and it arrives still Rooted
--
-- Each case pins a rule the review approved, on a bare board, plus the drops and the fights' rungs.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Bank = require("models.bank")
local AI = require("models.ai")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local BODIES = {
    character_ground_sloth = { tier = 2, organ = "utility_banked_turns", drop = "utility_sleepers_claws" },
    character_old_sloth = { tier = 3, organ = "utility_deep_bank", drop = "armor_hibernal_hide" },
    character_yeti = { tier = 2, organ = "utility_whiteout_roar", drop = "armor_yeti_hide_mantle" },
    character_dread_of_the_whiteout = { tier = 3, organ = "utility_drag_into_the_white", drop = "armor_whiteout_cloak" },
}
local TROPHY_CLASS = {
    utility_sleepers_claws = "monk", armor_hibernal_hide = "warden",
    armor_yeti_hide_mantle = "hunter", armor_whiteout_cloak = "ninja",
}
local ORGANS = {
    "utility_banked_turns", "utility_deep_bank", "utility_whiteout_roar", "utility_the_whiteout",
    "utility_drag_into_the_white",
}
-- id -> { kind, the bodies always there, the body that rolls and its band }
local FIGHTS = {
    encounter_sloth_glacier_grazers = { kind = "combat", fixed = { character_ground_sloth = 2 },
        rolls = "character_yeti", lo = 1, hi = 2 },
    encounter_sloth_the_old_sloth = { kind = "elite", fixed = { character_old_sloth = 1 },
        rolls = "character_ground_sloth", lo = 1, hi = 2 },
    encounter_sloth_dread_of_the_whiteout = { kind = "elite", fixed = { character_dread_of_the_whiteout = 1 },
        rolls = "character_yeti", lo = 2, hi = 3 },
}

local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 100, health or 100
    return spawn
end

local function wearing(x, y, id, health)
    local spawn = walker(x, y, health)
    Character.addItem(spawn.char, Item.instantiate(id))
    return spawn
end

local function board(n) return Fixture.new(n or 11, n or 11) end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function hit(c, target, amount, attacker)
    return Combat.dealFlatDamage(c, target, amount, { "physical" }, "test", attacker, { raw = true })
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "four beasts, each with its organ and its trophy, and the trophies on four shelves",
        fn = function()
            for id, want in pairs(BODIES) do
                local def = Character.defs[id]
                assert(def, id .. " exists")
                assert(def.race == "beast" and def.tier == want.tier, id .. " is a tier " .. want.tier .. " beast")
                local c = Character.instantiate(id)
                assert(itemNamed(c, want.organ), id .. " carries " .. want.organ)
                assert(def.drops and def.drops[1] == want.drop, id .. " drops " .. want.drop)
            end
            assert(Character.defs.character_ground_sloth.stats.movement == 1, "a ground sloth moves 1")
            assert(Character.defs.character_old_sloth.footprint.w == 2, "the Old Sloth stands on four tiles")
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal and def.bound, id .. " is an organ")
            end
            for id, class in pairs(TROPHY_CLASS) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.class == class, id .. " sits on the " .. class .. "'s shelf")
                assert(def.unstocked and def.unlockLevel == 9, id .. " is an unstocked find on Sloth's approach")
            end
            local fist = Item.defs.utility_sleepers_claws
            assert(fist.tags[1] == "fist", "Sleeper's Claws is a fist piece, worked by the bare hand")
        end,
    },
    {
        name = "three fights on the tundra's approach: the Grazers, the Old Sloth and the Dread",
        fn = function()
            for id, want in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e, id .. " exists")
                assert(e.kind == want.kind and e.rung == 1, id .. " is a rung-1 " .. want.kind)
                assert(e.condition({ biome = "tundra" }) and not e.condition({ biome = "forest" }),
                    id .. " is tundra-locked")
                local seen = {}
                for seed = 1, 40 do
                    local got = {}
                    for _, b in ipairs(e.composition({ depth = 9, seed = seed })) do got[b] = (got[b] or 0) + 1 end
                    for body, n in pairs(want.fixed) do
                        assert(got[body] == n, string.format("%s fields %d %s", id, n, body))
                    end
                    local rolled = got[want.rolls] or 0
                    assert(rolled >= want.lo and rolled <= want.hi,
                        string.format("%s rolls %d-%d %s (got %d)", id, want.lo, want.hi, want.rolls, rolled))
                    seen[rolled] = true
                end
                assert(seen[want.lo] and seen[want.hi], id .. " rolls both ends of its band")
            end
        end,
    },
    -- ------------------------------------------------------------------------------ the ground sloth
    {
        name = "Banked: with no foe in reach a sloth does nothing, and each idle turn is banked, up to 3",
        fn = function()
            local c = Fixture.combat(board(), walker(1, 1), { unit("character_ground_sloth", 8, 8) })
            local sloth = one(c, "character_ground_sloth")
            openTurn(c, sloth)
            local plan = AI.plan(c, sloth)
            assert(plan and plan.wait, "nothing within its 1 step and its claws: it waits")
            for _ = 1, 4 do Trait.onAnyTurnEnd(c, sloth) end
            assert(Bank.count(sloth) == 3, "the turns are banked, never past 3 (got " .. Bank.count(sloth) .. ")")
            assert(Status.has(sloth, "status_banked"), "and the bank is on the badge")
        end,
    },
    {
        name = "Banked: a foe within a step and a swing is in reach, and the sloth does not wait",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 7), { unit("character_ground_sloth", 5, 5) })
            local sloth = one(c, "character_ground_sloth")
            openTurn(c, sloth)
            local plan = AI.plan(c, sloth)
            assert(plan and not plan.wait, "a foe two tiles off is one step and one swing away")
        end,
    },
    {
        name = "Banked: the next swing lands once per banked turn and once more, and spends the bank",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 6, 900), { unit("character_ground_sloth", 5, 5) })
            local foe, sloth = c.units[1], one(c, "character_ground_sloth")
            local before = hp(foe)
            assert(Fixture.strike(c, sloth, foe, "weapon_ground_sloth_claws"), "it swings")
            local once = before - hp(foe)
            assert(once > 0, "an empty bank swings once")
            assert(Bank.count(sloth) == 0, "a turn it swung in is not banked (the swing ended it)")
            Bank.add(c, sloth, 2, 3)
            before = hp(foe)
            assert(Fixture.strike(c, sloth, foe, "weapon_ground_sloth_claws"), "it swings again")
            assert(before - hp(foe) == once * 3, "two banked turns: three landings")
            assert(Bank.count(sloth) == 0, "and the bank is spent")
        end,
    },
    {
        name = "Banked: a blow that lands on it knocks one turn out; a burn ticking does not",
        fn = function()
            local c = Fixture.combat(board(), walker(1, 1), { unit("character_ground_sloth", 8, 8) })
            local foe, sloth = c.units[1], one(c, "character_ground_sloth")
            Bank.add(c, sloth, 3, 3)
            hit(c, sloth, 2, foe)
            assert(Bank.count(sloth) == 2, "a blow knocks a turn out")
            Combat.dealFlatDamage(c, sloth, 2, { "fire" }, "a burn", nil, { raw = true })
            assert(Bank.count(sloth) == 2, "a wound with no striker is not a blow")
        end,
    },
    -- ------------------------------------------------------------------------------ the old sloth
    {
        name = "the Old Sloth opens Dormant with a full bank of 5, and a blow wakes it a turn lighter",
        fn = function()
            local c = Fixture.combat(board(), walker(1, 1), { unit("character_old_sloth", 5, 5) })
            local foe, old = c.units[1], one(c, "character_old_sloth")
            assert(Status.has(old, "status_dormant"), "it opens Dormant")
            assert(Bank.count(old) == 5, "with a full bank of 5")
            Trait.onAnyTurnEnd(c, old)
            assert(Bank.count(old) == 5, "and never past its cap")
            hit(c, old, 3, foe)
            assert(not Status.has(old, "status_dormant") and Status.has(old, "status_rude_awakening"),
                "a blow wakes it into Rude Awakening")
            assert(Bank.count(old) == 4, "and knocks a turn out of the bank")
        end,
    },
    {
        name = "the Old Sloth spends its bank as ring sweeps: every foe beside it, once per turn banked and once more",
        fn = function()
            local c = Fixture.combat(board(),
                { walker(4, 5, 900), walker(7, 6, 900), walker(5, 8, 900) },
                { unit("character_old_sloth", 5, 5), unit("character_ground_sloth", 5, 4) })
            local west, east, far = c.units[1], c.units[2], c.units[3]
            local old, grazer = one(c, "character_old_sloth"), one(c, "character_ground_sloth")
            hit(c, old, 1, far) -- awake, and four turns left in the bank
            assert(Bank.count(old) == 4)
            -- Rude Awakening ends with its first turn, so the two sweeps below would differ by its +4: measure the
            -- bank alone.
            Status.remove(c, old, "status_rude_awakening")
            local w0, e0, f0, g0 = hp(west), hp(east), hp(far), hp(grazer)
            assert(Fixture.strike(c, old, west, "weapon_megatherium_sweep"), "the sweep goes round")
            local five = w0 - hp(west)
            assert(five > 0 and e0 - hp(east) == five, "both foes beside it take the same sweeps")
            assert(hp(far) == f0, "a foe two tiles off is outside the ring")
            assert(hp(grazer) == g0, "its own grazer beside it is not swept")
            assert(Bank.count(old) == 0, "the bank is spent")
            local w1 = hp(west)
            assert(Fixture.strike(c, old, west, "weapon_megatherium_sweep"), "and an empty bank sweeps once")
            assert(five == (w1 - hp(west)) * 5, "four banked turns were five sweeps")
        end,
    },
    -- ------------------------------------------------------------------------------ the yeti
    {
        name = "Whiteout Roar: a foe within 4 with no ally beside it is Rooted; a pair is not, nor one beyond 4",
        fn = function()
            local c = Fixture.combat(board(),
                { walker(5, 8), walker(8, 5), walker(8, 6), walker(5, 10) },
                { unit("character_yeti", 5, 5) })
            local lone, pairA, pairB, far = c.units[1], c.units[2], c.units[3], c.units[4]
            Trait.onAnyTurnStart(c, one(c, "character_yeti"))
            assert(Status.has(lone, "status_root"), "alone within 4: frozen with fear")
            assert(not Status.has(pairA, "status_root") and not Status.has(pairB, "status_root"), "a pair is not")
            assert(not Status.has(far, "status_root"), "and beyond 4 the roar does not reach")
        end,
    },
    {
        name = "Yeti-Hide Mantle: at the start of your turn only the nearest lonely foe within 3 is Rooted",
        fn = function()
            local c = Fixture.combat(board(), wearing(5, 5, "armor_yeti_hide_mantle"),
                { unit("character_yeti", 5, 7), unit("character_yeti", 8, 5), unit("character_yeti", 5, 9) })
            local me, near, next, far = c.units[1], c.units[2], c.units[3], c.units[4]
            Trait.onAnyTurnStart(c, me)
            assert(Status.has(near, "status_root"), "the nearest lonely foe is Rooted")
            assert(not Status.has(next, "status_root"), "only the one")
            assert(not Status.has(far, "status_root"), "and nothing beyond 3")
        end,
    },
    -- ------------------------------------------------------------------------------ the dread of the whiteout
    {
        name = "Whiteout: the Dread is Unseen to foes more than 2 tiles away, until she is Limned",
        fn = function()
            local c = Fixture.combat(board(), walker(1, 1), { unit("character_dread_of_the_whiteout", 5, 5) })
            local dread = one(c, "character_dread_of_the_whiteout")
            assert(Status.concealedAt(dread, c, 3), "three tiles off, she is not there")
            assert(not Status.concealedAt(dread, c, 2), "two tiles off, she is")
            Status.apply(c, dread, "status_limned", {})
            assert(not Status.concealedAt(dread, c, 6), "Limned, she is seen from anywhere")
            local c2 = Fixture.combat(board(), wearing(5, 5, "armor_whiteout_cloak"), { unit("character_yeti", 1, 1) })
            assert(Status.concealedAt(c2.units[1], c2, 3), "the Whiteout Cloak does the same for its wearer")
        end,
    },
    {
        name = "Drag Into the White: she hauls a Rooted foe 3 tiles toward her, and it arrives still Rooted",
        fn = function()
            local c = Fixture.combat(board(), { walker(7, 5), walker(1, 9) },
                { unit("character_dread_of_the_whiteout", 1, 5) })
            local rooted, free = c.units[1], c.units[2]
            local dread = one(c, "character_dread_of_the_whiteout")
            Status.apply(c, rooted, "status_root", {})
            Trait.onAnyTurnStart(c, dread)
            assert(rooted.x == 4 and rooted.y == 5, "hauled 3 tiles toward her (now at " .. rooted.x .. "," .. rooted.y .. ")")
            assert(Status.has(rooted, "status_root"), "and still Rooted when it gets there")
            assert(free.x == 1 and free.y == 9, "a body that is not Rooted is not hers to take")
        end,
    },
    -- ------------------------------------------------------------------------------ the trophies
    {
        name = "Sleeper's Claws: each turn ended without attacking banks a blow, and the next fist lands once more per blow",
        fn = function()
            local c = Fixture.combat(board(), wearing(5, 5, "utility_sleepers_claws"),
                { unit("character_yeti", 5, 6, { stats = { health = 900 } }) })
            local me, foe = c.units[1], c.units[2]
            local before = hp(foe)
            assert(Fixture.strike(c, me, foe, me.char.unarmed), "a bare-handed strike")
            local once = before - hp(foe)
            assert(once > 0, "lands once with nothing banked")
            assert(Bank.count(me) == 0, "a turn you attacked in banks nothing (the strike ended it)")
            Trait.onAnyTurnEnd(c, me)
            Trait.onAnyTurnEnd(c, me)
            Trait.onAnyTurnEnd(c, me)
            assert(Bank.count(me) == 3, "idle turns bank a blow each, up to 3")
            before = hp(foe)
            assert(Fixture.strike(c, me, foe, me.char.unarmed), "the fist again")
            assert(before - hp(foe) == once * 4, "three banked blows: four landings")
            assert(Bank.count(me) == 0, "and the bank is spent")
        end,
    },
    {
        name = "Hibernal Hide: the blow that wakes you from Sleep deals half, and your first blow after deals 50% more",
        fn = function()
            local c = Fixture.combat(board(), wearing(5, 5, "armor_hibernal_hide", 300),
                { unit("character_yeti", 5, 6, { stats = { health = 900 } }) })
            local me, foe = c.units[1], c.units[2]
            local claws = itemNamed(foe.char, "weapon_yeti_claws")
            local awake = Combat.computeDamage(c, foe, me, claws)
            Status.apply(c, me, "status_sleep", { applier = foe })
            assert(Status.has(me, "status_sleep"), "the sleep lands")
            local asleep = Combat.computeDamage(c, foe, me, claws)
            assert(asleep == math.floor(awake * 0.5 + 0.5), "asleep, a blow is quoted at half (" .. awake .. " -> " .. asleep .. ")")
            local mine = Combat.computeDamage(c, me, foe, me.char.unarmed)
            local before = hp(me)
            assert(Fixture.strike(c, foe, me, claws), "the yeti strikes the sleeper")
            assert(before - hp(me) == asleep, "and the waking blow lands at half")
            assert(not Status.has(me, "status_sleep"), "it wakes you")
            local primed = Combat.computeDamage(c, me, foe, me.char.unarmed)
            assert(primed > mine, "your first blow after waking is the heavier (" .. mine .. " -> " .. primed .. ")")
            assert(Fixture.strike(c, me, foe, me.char.unarmed), "you swing")
            assert(Combat.computeDamage(c, me, foe, me.char.unarmed) == mine, "and only the first")
            assert(Combat.computeDamage(c, foe, me, claws) == awake, "the padding left with the sleep")
        end,
    },
}
