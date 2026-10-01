-- Tests for PRIDE'S APPROACH BEASTS AND THE TITAN (2026-09-30, approved on Pride's bestiary review): the Lioness,
-- the Lion, the Peacock-Basilisk and the Titan, their rules, their four fights and their four trophies.
--
--   The King Eats First      while a Lion of her side stands, a lioness's blow leaves a foe at 1, and Rooted
--   The Lion's Share         the Lion goes for held prey first; his kill heals every lioness 20% and Rattles foes
--                            within 2
--   The Gaze That Is Admired a foe within 3 that ends its turn without attacking the bird is Stunned
--   Chained                  the Titan moves 1, reaches 2 and shoves 2; below half the chains break (+2 move, +4)
--
-- Each case pins a rule the review approved, on a bare board. Not the wood's sabertooths: no hiding here, and the
-- wood's "The Pride" keeps its name.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Race = require("models.race")
local Status = require("models.status")
local Trait = require("models.trait")
local AI = require("models.ai")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local BODIES = {
    character_lioness = { race = "beast", tier = 2, organ = "utility_the_king_eats_first", drop = "utility_hold_the_quarry" },
    character_lion = { race = "beast", tier = 3, organ = "utility_the_lions_share", drop = "armor_golden_mane" },
    character_peacock_basilisk = { race = "beast", tier = 2, organ = "utility_the_admired_gaze", drop = "utility_peacocks_train" },
    character_titan = { race = "giant", tier = 3, organ = "utility_the_chains_break", drop = "weapon_titans_chain" },
}
local TROPHY_CLASS = {
    utility_hold_the_quarry = "hunter", armor_golden_mane = "knight",
    utility_peacocks_train = "rogue", weapon_titans_chain = "barbarian",
}
local ORGANS = {
    "utility_the_king_eats_first", "utility_the_lions_share", "utility_the_admired_gaze",
    "utility_the_gods_chains", "utility_the_chains_break",
}
local FIGHTS = {
    encounter_pride_the_hunt = { character_lion = 1, character_lioness = 2 },
    encounter_pride_the_display = { character_peacock_basilisk = 1 },
    encounter_pride_the_chained = { character_titan = 1 },
}

local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 100, health or 100
    return spawn
end

local function board(n) return Fixture.new(n or 11, n or 11) end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function maxHp(u) return Combat.unreservedMax(u.char, "health") end

local function hit(c, target, amount, attacker)
    return Combat.dealFlatDamage(c, target, amount, { "physical" }, "test", attacker, { raw = true })
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "four bodies: three beasts and a giant, each with its organ and its trophy",
        fn = function()
            for id, want in pairs(BODIES) do
                local def = Character.defs[id]
                assert(def, id .. " exists")
                assert(def.race == want.race and def.tier == want.tier, id .. " is a tier " .. want.tier .. " " .. want.race)
                local c = Character.instantiate(id)
                assert(itemNamed(c, want.organ), id .. " carries " .. want.organ)
                assert(def.drops and def.drops[1] == want.drop, id .. " drops " .. want.drop)
            end
            local giant = Race.get("giant")
            assert(giant.kind == "humanoid" and not giant.playable, "a giant is a humanoid record nobody hires")
            assert(Character.instantiate("character_titan").kind == "humanoid", "and the Titan stands on it")
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal and def.bound, id .. " is an organ")
            end
            for id, class in pairs(TROPHY_CLASS) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.class == class, id .. " sits on the " .. class .. "'s shelf")
                assert(def.unstocked and def.unlockLevel == 13, id .. " is an unstocked find on Pride's approach")
            end
        end,
    },
    {
        name = "three fights on the spire's approach, none of them named The Pride, the Court the Hunt's top",
        fn = function()
            for id, cast in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e, id .. " exists")
                assert(e.kind == "combat" and e.rung == 1, id .. " is approach traffic")
                assert(e.condition({ biome = "spire" }) and not e.condition({ biome = "forest" }), id .. " is spire-locked")
                assert(e.name ~= "The Pride", id .. " does not take the wood's name")
                local got = {}
                for _, b in ipairs(e.composition({ depth = 13 })) do got[b] = (got[b] or 0) + 1 end
                for body, n in pairs(cast) do
                    assert(got[body] == n, string.format("%s fields %d %s (got %s)", id, n, body, tostring(got[body])))
                end
            end
            local display = Encounter.get("encounter_pride_the_display").composition({ depth = 13 })
            local chained = Encounter.get("encounter_pride_the_chained").composition({ depth = 13 })
            assert(display[2] == "character_gilded_page", "the bird is shown off before Pride's pages")
            assert(chained[2] == "character_gilded_sworn", "the Titan walks with gilded sworn")
            -- The Lion's Court was approved as a heavier stop; one cast is one stop (encounter_spec), so it is the
            -- top of the Hunt's band: two or three lionesses, never a fourth.
            local seen = {}
            for seed = 1, 40 do
                local n = 0
                for _, b in ipairs(Encounter.get("encounter_pride_the_hunt").composition({ depth = 13, seed = seed })) do
                    if b == "character_lioness" then n = n + 1 end
                end
                seen[n] = true
            end
            assert(seen[2] and seen[3] and not seen[1] and not seen[4], "the Hunt rolls two or three lionesses")
            assert(not Encounter.get("encounter_pride_the_lions_court"), "and the Court is not a second blueprint")
        end,
    },
    -- ------------------------------------------------------------------------------ the lions
    {
        name = "the King Eats First: while the Lion stands, a lioness leaves a foe at 1 and Rooted",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 6, 40),
                { unit("character_lioness", 5, 5), unit("character_lion", 8, 8) })
            local foe, lioness, lion = c.units[1], one(c, "character_lioness"), one(c, "character_lion")
            hit(c, foe, 10, lioness)
            assert(hp(foe) == 30 and not Status.has(foe, "status_root"), "a blow that leaves it standing does nothing more")
            hit(c, foe, 999, lioness)
            assert(foe.alive and hp(foe) == 1, "a killing blow holds it at 1")
            assert(Status.has(foe, "status_root"), "and it is Rooted there, held for him")
            hit(c, lion, 9999, foe)
            assert(not lion.alive, "the Lion falls")
            hit(c, foe, 5, lioness)
            assert(not foe.alive, "and the lionesses kill freely")
        end,
    },
    {
        name = "the Lion's Share: he goes for held prey first",
        fn = function()
            local c = Fixture.combat(board(), { walker(5, 6, 100), walker(7, 5, 100) },
                { unit("character_lion", 5, 5) })
            local near, held, lion = c.units[1], c.units[2], one(c, "character_lion")
            held.char.stats.health.current = 1
            Status.apply(c, held, "status_root", {})
            openTurn(c, lion)
            local plan = AI.plan(c, lion)
            assert(plan and plan.target == held, "the held body decides his turn, not the one beside him "
                .. tostring(near.x))
        end,
    },
    {
        name = "the Lion's Share: his kill roars, healing every lioness 20% and Rattling foes within 2",
        fn = function()
            local c = Fixture.combat(board(), { walker(5, 6, 10), walker(5, 7, 100), walker(10, 10, 100) },
                { unit("character_lion", 5, 5), unit("character_lioness", 1, 1) })
            local prey, near, far = c.units[1], c.units[2], c.units[3]
            local lion, lioness = one(c, "character_lion"), one(c, "character_lioness")
            lioness.char.stats.health.current = 10
            hit(c, prey, 9999, lion)
            assert(not prey.alive, "he makes the kill")
            assert(hp(lioness) == 10 + math.floor(maxHp(lioness) * 0.2 + 0.5), "the lioness across the board heals 20%")
            assert(Status.has(near, "status_rattled"), "a foe within 2 is Rattled")
            assert(not Status.has(far, "status_rattled"), "a foe beyond 2 is not")
            assert(Status.get(near, "status_rattled").remaining < 100, "and for a fight's while, not an injury's")
        end,
    },
    {
        name = "Hold the Quarry: a blow that takes a foe below a quarter Roots it",
        fn = function()
            local bearer = walker(5, 6, 100)
            Character.addItem(bearer.char, Item.instantiate("utility_hold_the_quarry"))
            local c = Fixture.combat(board(), bearer, { unit("character_lioness", 5, 5, { stats = { health = 40 } }) })
            local me, foe = c.units[1], one(c, "character_lioness")
            hit(c, foe, 20, me)
            assert(not Status.has(foe, "status_root"), "half is not a quarter")
            hit(c, foe, 12, me)
            assert(hp(foe) == 8 and Status.has(foe, "status_root"), "crossing below 10 of 40 Roots it")
            Status.remove(c, foe, "status_root")
            hit(c, foe, 2, me)
            assert(not Status.has(foe, "status_root"), "a blow on a body already under the line crossed nothing")
        end,
    },
    {
        name = "Golden Mane: a kill heals allies within 2 by 10% and Rattles foes within 2",
        fn = function()
            local bearer = walker(5, 5, 100)
            Character.addItem(bearer.char, Item.instantiate("armor_golden_mane"))
            local c = Fixture.combat(board(), { bearer, walker(5, 7, 100), walker(10, 10, 100) },
                { unit("character_lioness", 6, 5), unit("character_lioness", 4, 5) })
            local me, ally, far = c.units[1], c.units[2], c.units[3]
            local prey, other = c.units[4], c.units[5]
            ally.char.stats.health.current, far.char.stats.health.current = 50, 50
            hit(c, prey, 9999, me)
            assert(not prey.alive, "the bearer makes the kill")
            assert(hp(ally) == 60, "the ally within 2 heals 10%")
            assert(hp(far) == 50, "the ally across the board does not")
            assert(Status.has(other, "status_rattled"), "the foe within 2 is Rattled")
        end,
    },
    -- ------------------------------------------------------------------------------ the peacock-basilisk
    {
        name = "the Gaze: a foe within 3 that ends its turn without attacking the bird is Stunned",
        fn = function()
            local c = Fixture.combat(board(), { walker(5, 7, 100), walker(5, 10, 100), walker(7, 5, 100) },
                { unit("character_peacock_basilisk", 5, 5) })
            local idle, far, striker = c.units[1], c.units[2], c.units[3]
            local bird = one(c, "character_peacock_basilisk")
            Trait.onAnyTurnEnd(c, idle)
            assert(Status.has(idle, "status_stun"), "within 3 and it looked away: Stunned")
            Trait.onAnyTurnEnd(c, far)
            assert(not Status.has(far, "status_stun"), "beyond 3 the gaze does not reach")
            hit(c, bird, 3, striker)
            Trait.onAnyTurnEnd(c, striker)
            assert(not Status.has(striker, "status_stun"), "a body that struck it this turn is spared")
            c.turnCount = c.turnCount + 1
            Trait.onAnyTurnEnd(c, striker)
            assert(Status.has(striker, "status_stun"), "but only for that turn")
        end,
    },
    {
        name = "the Gaze: a swing aimed at the bird counts even when it misses",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 6, 100), { unit("character_peacock_basilisk", 5, 5) })
            local foe, bird = c.units[1], one(c, "character_peacock_basilisk")
            Trait.onAnyCast(c, foe, { item = {}, ability = { target = "enemy", damage = 5 }, tx = bird.x, ty = bird.y })
            Trait.onAnyTurnEnd(c, foe)
            assert(not Status.has(foe, "status_stun"), "it looked at the bird, so it is not Stunned")
        end,
    },
    {
        name = "Peacock's Train: foes within 2 that ignore the bearer are Rattled, not Stunned",
        fn = function()
            local bearer = walker(5, 5, 100)
            Character.addItem(bearer.char, Item.instantiate("utility_peacocks_train"))
            local c = Fixture.combat(board(), bearer,
                { unit("character_lioness", 5, 7), unit("character_lioness", 5, 8) })
            local near, beyond = c.units[2], c.units[3]
            Trait.onAnyTurnEnd(c, near)
            Trait.onAnyTurnEnd(c, beyond)
            assert(Status.has(near, "status_rattled") and not Status.has(near, "status_stun"), "within 2: Rattled")
            assert(not Status.has(beyond, "status_rattled"), "at 3: nothing")
        end,
    },
    -- ------------------------------------------------------------------------------ the titan
    {
        name = "the Titan: chained to 1 tile a turn until half, then +2 movement and +4 damage",
        fn = function()
            local c = Fixture.combat(board(), walker(1, 1, 100), { unit("character_titan", 5, 5) })
            local foe, titan = c.units[1], one(c, "character_titan")
            assert(Combat.moveBudget(titan) == 1, "the chains hold it to a tile a turn")
            local dmg = Combat.flatStat(titan, "damage")
            hit(c, titan, hp(titan) - math.floor(maxHp(titan) / 2) + 1, foe)
            assert(titan.alive and hp(titan) < maxHp(titan) / 2, "below half")
            assert(Combat.moveBudget(titan) == 3, "the chains break: +2 movement")
            assert(Combat.flatStat(titan, "damage") == dmg + 4, "and +4 damage")
        end,
    },
    {
        name = "the Titan's Hanging Chain reaches 2 and shoves 2",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 7, 300), { unit("character_titan", 5, 5) })
            local foe, titan = c.units[1], one(c, "character_titan")
            local before = hp(foe)
            assert(Fixture.strike(c, titan, foe, "weapon_hanging_chain"), "the chain reaches 2 tiles")
            assert(hp(foe) < before, "it lands")
            assert(foe.x == 5 and foe.y == 9, "and throws the body 2 tiles back")
        end,
    },
    {
        name = "Titan's Chain: sweeps foes within 2, shoves each 1, a collision is the hit again, and past half 2",
        fn = function()
            local def = Item.defs["weapon_titans_chain"]
            assert(Item.archetype(def) == "mace", "a chain is a displacement weapon: a mace")
            local bearer = walker(5, 5, 100)
            bearer.char.inventory[1] = Item.instantiate("weapon_titans_chain")
            local c = Fixture.combat(board(), { bearer, walker(4, 5, 100) },
                { unit("character_lioness", 5, 6, { stats = { health = 300 } }),
                  unit("character_lioness", 5, 3, { stats = { health = 300 } }),
                  unit("character_lioness", 5, 2, { stats = { health = 300 } }),
                  unit("character_lioness", 9, 9, { stats = { health = 300 } }) })
            local me, ally = c.units[1], c.units[2]
            local near, mid, behind, far = c.units[3], c.units[4], c.units[5], c.units[6]
            local allyHp, farHp, behindHp = hp(ally), hp(far), hp(behind)
            assert(Fixture.strike(c, me, near, "weapon_titans_chain"), "the sweep goes round")
            assert(hp(ally) == allyHp, "an ally inside it is not struck")
            assert(hp(far) == farHp, "a foe beyond 2 is not struck")
            assert(near.y == 7, "the foe beside it is shoved 1")
            assert(mid.y == 3 and hp(behind) < behindHp, "the foe shoved into a body stays and the body takes the hit")

            -- Past half: the same swing shoves 2.
            local c2 = Fixture.combat(board(), walker(5, 5, 100),
                { unit("character_lioness", 5, 6, { stats = { health = 300 } }) })
            local me2, foe2 = c2.units[1], c2.units[2]
            me2.char.inventory[1] = Item.instantiate("weapon_titans_chain")
            me2.char.stats.health.current = 40
            assert(Fixture.strike(c2, me2, foe2, "weapon_titans_chain"), "the sweep goes round")
            assert(foe2.y == 8, "below half the shove goes 2")
        end,
    },
}
