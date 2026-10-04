-- Tests for SLOTH'S DREAMERS (slice E of "Sloth's Bestiary", 2026-10-04): the seat's sleep-and-root bodies, their
-- rules, the fights they stand in and what they drop.
--
--   Poppy-Moth     Poppy Dust -- struck (or felled), it bursts, and every body beside it falls Asleep, either side
--   Baku           Dream-Eating -- at the top of its turn it feeds on every Asleep or Dormant body within 3: a
--                  tenth of its health and +2 Damage each
--   the Old Spruce Will Not Be Hurried -- never attacks; its roots spread a tile each turn and nobody crosses them;
--                  a body ending its turn beside it is Rooted
--   the trophies   the Poppy Censer (Apothecary), Baku's Ward (Exorcist), the Spruce Staff (Druid)
-- Each case pins a rule the review approved, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Arena = require("models.arena")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Wall = require("models.wall")
local Dreamers = require("models.sloth_dreamers")
local Fixture = require("tests.support.fixture")

local unit, hp = Fixture.unit, Fixture.hp

local BODIES = { "character_poppy_moth", "character_baku", "character_old_spruce" }
local TROPHIES = {
    utility_poppy_censer = { body = "character_poppy_moth", class = "apothecary" },
    utility_bakus_ward = { body = "character_baku", class = "exorcist" },
    weapon_spruce_staff = { body = "character_old_spruce", class = "druid" },
}
local ORGANS = {
    "utility_poppy_dust", "utility_dream_eating", "utility_will_not_be_hurried",
    "weapon_moth_wings", "weapon_baku_tusks",
}

local function board() return Fixture.new(11, 11) end

-- A plain body to stand on the board: an archer with an empty grid and a known health.
local function body(x, y, items)
    return unit("character_archer", x, y, { isolate = "bare", items = items, stats = { health = 100 } })
end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function strike(c, target, n, from)
    Combat.dealFlatDamage(c, target, n, { "physical" }, "test", from, { raw = true })
end

local function asleep(u) return Status.has(u, "status_sleep") end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the moth and Baku are beasts, the Spruce is an elemental plant that never walks, all on the seat's tiers",
        fn = function()
            local moth, baku, tree = Character.defs.character_poppy_moth, Character.defs.character_baku,
                Character.defs.character_old_spruce
            assert(moth.race == "beast" and moth.tier == 1, "the Poppy-Moth is tier-1 traffic")
            assert(baku.race == "beast" and baku.tier == 3, "Baku is a tier-3 chimera, a beast")
            assert(tree.race == "elemental" and tree.tier == 3, "no plant race: the Spruce is the nearest, an elemental")
            assert(tree.plant == true, "and the grove reads it as a plant")
            assert(tree.stats.movement == 0 and tree.unarmed == false, "it does not walk and it does not strike")
            assert(tree.resist.slash > 0 and tree.resist.fire < 0, "it resists slash and burns badly")
            assert(tree.stats.health >= 120, "a great deal of health")
            local c = Character.instantiate("character_poppy_moth")
            assert(Fixture.itemNamed(c, "utility_poppy_dust"), "the moth carries its dust")
            assert(Item.defs.utility_poppy_dust.tags[2] == "flying", "and its wings")
        end,
    },
    {
        name = "every trophy is an unstocked find on its body's drop list, on a real shelf; the organs are the bodies' own",
        fn = function()
            for id, want in pairs(TROPHIES) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.unstocked, id .. " is a trophy: seen on the rack, never sold")
                assert(def.class == want.class, id .. " sits on the " .. want.class .. " shelf")
                local listed = false
                for _, d in ipairs(Character.defs[want.body].drops or {}) do listed = listed or d == id end
                assert(listed, id .. " is on " .. want.body .. "'s drop list")
            end
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal, id .. " is a body's own and cannot be taken")
                if def.type == "utility" then assert(def.bound, id .. " is an organ, bound to the body") end
            end
            local staff = Item.defs.weapon_spruce_staff
            assert(staff.waitBehavior and staff.waitBehavior.kind == "focus", "the Spruce Staff is a staff: Wait is Focus")
        end,
    },
    {
        name = "Baku stands in a cloud of four moths and the Sleeping Wood is the Spruce and four, both on the seat",
        fn = function()
            local baku = Encounter.get("encounter_sloth_baku")
            assert(baku.kind == "elite" and baku.rung == 2, "Baku is an elite, locked to the seat")
            local wood = Encounter.get("encounter_sloth_the_sleeping_wood")
            assert(wood.kind == "combat" and wood.rung == 2 and wood.weight == 3, "the Sleeping Wood is seat traffic")
            for _, e in ipairs({ baku, wood }) do
                assert(e.condition({ biome = "tundra" }) and not e.condition({ biome = "desert" }), "locked to the tundra")
            end
            local function count(ids, id)
                local n = 0
                for _, x in ipairs(ids) do if x == id then n = n + 1 end end
                return n
            end
            local rated = Arena.resolveComposition(baku.composition, { depth = 10 })
            assert(count(rated, "character_baku") == 1 and count(rated, "character_poppy_moth") == 4,
                "Baku rates with a cloud of 4")
            rated = Arena.resolveComposition(wood.composition, { depth = 10 })
            assert(count(rated, "character_old_spruce") == 1 and count(rated, "character_poppy_moth") == 4,
                "the Sleeping Wood rates as the Spruce and 4 moths")
            assert(Arena.enemyCap({ encounterKind = "combat", encounterCap = wood.enemyCap }) >= #rated,
                "and its own ceiling seats all five")
            for seed = 1, 20 do
                local n = count(Arena.resolveComposition(baku.composition, { depth = 10, seed = seed }),
                    "character_poppy_moth")
                assert(n >= 4 and n <= 5, "Baku's cloud rolls 4-5, never past the elite tier")
            end
        end,
    },
    -- ------------------------------------------------------------------------------ Poppy Dust
    {
        name = "Poppy Dust: a struck moth puts every body beside it to sleep, either side, and nobody further off",
        fn = function()
            local c = Fixture.combat(board(), { body(5, 6), body(5, 9) },
                { unit("character_poppy_moth", 5, 5), unit("character_poppy_moth", 6, 5) })
            local sword, archer = c.units[1], c.units[2]
            local moth = c.units[3]
            local other = c.units[4]
            strike(c, moth, 2, sword)
            assert(moth.alive, "a scratch")
            assert(asleep(sword), "the striker beside it falls Asleep")
            assert(asleep(other), "and so does the moth beside it: either side")
            assert(not asleep(archer), "a body three tiles off is untouched: kill them from range")
        end,
    },
    {
        name = "Poppy Dust: a blow that fells the moth still bursts it, and a moth the cloud put under still bursts",
        fn = function()
            local c = Fixture.combat(board(), body(5, 6), { unit("character_poppy_moth", 5, 5) })
            local sword, moth = c.units[1], c.units[2]
            strike(c, moth, 999, sword)
            assert(not moth.alive, "the kill")
            assert(asleep(sword), "a melee kill puts the striker to sleep")

            local c2 = Fixture.combat(board(), body(5, 6), { unit("character_poppy_moth", 5, 5) })
            local foe, moth2 = c2.units[1], c2.units[2]
            Status.apply(c2, moth2, "status_sleep", { applier = foe })
            assert(asleep(moth2), "the moth is under")
            strike(c2, moth2, 1, foe)
            assert(asleep(foe), "and hit, it bursts all the same -- the dust is not a reflex")
            assert(not asleep(moth2), "while the blow wakes the moth itself")
        end,
    },
    -- ------------------------------------------------------------------------------ Dream-Eating
    {
        name = "Dream-Eating: Baku heals a tenth and gains +2 Damage for each Asleep or Dormant body within 3",
        fn = function()
            local c = Fixture.combat(board(), { body(5, 7), body(5, 9) },
                { unit("character_baku", 5, 5), unit("character_poppy_moth", 3, 5), unit("character_poppy_moth", 9, 5) })
            local near, far = c.units[1], c.units[2]
            local baku = one(c, "character_baku")
            local moth, farMoth = c.units[4], c.units[5]
            Status.apply(c, near, "status_sleep", { applier = moth })
            Status.apply(c, moth, "status_dormant", { applier = moth })
            Status.apply(c, far, "status_sleep", { applier = moth })     -- 4 away: out of reach
            Status.apply(c, farMoth, "status_sleep", { applier = moth }) -- 4 away: out of reach
            assert(asleep(near) and Status.has(moth, "status_dormant"), "two under within 3, one on each side")
            local max = Combat.unreservedMax(baku.char, "health")
            strike(c, baku, 50, far)
            assert(asleep(near), "a blow on Baku wakes nobody else")
            local before = hp(baku)
            local damage = Combat.flatStat(baku, "damage")
            Trait.onAnyTurnStart(c, baku)
            assert(hp(baku) == before + 2 * math.floor(max * 0.1), "a tenth of its health for each of two")
            assert(Status.get(baku, "status_dream_fed").magnitude == 2, "fed twice")
            assert(Combat.flatStat(baku, "damage") == damage + 4, "+2 Damage for each")
        end,
    },
    {
        name = "Dream-Eating: wake the sleepers and it is starved on its very next turn",
        fn = function()
            local c = Fixture.combat(board(), body(5, 7), { unit("character_baku", 5, 5) })
            local sleeper, baku = c.units[1], one(c, "character_baku")
            Status.apply(c, sleeper, "status_sleep", { applier = baku })
            Trait.onAnyTurnStart(c, baku)
            assert(Status.has(baku, "status_dream_fed"), "it feeds")
            strike(c, sleeper, 1, baku)
            assert(not asleep(sleeper), "hit your own sleeper and it wakes")
            Trait.onAnyTurnStart(c, baku)
            assert(not Status.has(baku, "status_dream_fed"), "and the meal is gone")
        end,
    },
    -- ------------------------------------------------------------------------------ the Old Spruce
    {
        name = "Will Not Be Hurried: the roots spread a tile each turn toward the company, and nobody crosses them",
        fn = function()
            local c = Fixture.combat(board(), body(5, 9), { unit("character_old_spruce", 5, 5) })
            local tree = one(c, "character_old_spruce")
            assert(#Dreamers.rootsOf(c, tree) == 0, "no roots at the bell")
            Trait.onAnyTurnEnd(c, tree)
            local roots = Dreamers.rootsOf(c, tree)
            assert(#roots == 1 and roots[1].x == 5 and roots[1].y == 6, "one root, beside it, toward the company")
            Trait.onAnyTurnEnd(c, tree)
            roots = Dreamers.rootsOf(c, tree)
            assert(#roots == 2, "a second the next turn")
            local grown = roots[2]
            assert(grown.x == 5 and grown.y == 7, "spreading on from the first")
            assert(Combat.objectBlocksAt(c, grown.x, grown.y), "a root bars the way")
            assert(Wall.at(c, grown.x, grown.y).sightCost == 0, "but not a line of sight: shoot over it")
            assert(Item.defs.utility_will_not_be_hurried.traits[1] == "trait_will_not_be_hurried")
            assert(#Character.instantiate("character_old_spruce").inventory > 0)
        end,
    },
    {
        name = "Will Not Be Hurried: a body that ends its turn beside the tree is Rooted, on either side",
        fn = function()
            local c = Fixture.combat(board(), { body(5, 6), body(8, 8) },
                { unit("character_old_spruce", 5, 5), unit("character_poppy_moth", 4, 5) })
            local beside, apart = c.units[1], c.units[2]
            local moth = one(c, "character_poppy_moth")
            Trait.onAnyTurnEnd(c, beside)
            assert(Status.has(beside, "status_root"), "beside it at the end of a turn: Rooted")
            Trait.onAnyTurnEnd(c, apart)
            assert(not Status.has(apart, "status_root"), "further off: free")
            Trait.onAnyTurnEnd(c, moth)
            assert(Status.has(moth, "status_root"), "and it roots its own side's moths as well")
            assert(Status.get(beside, "status_root").remaining >= Status.TICKS_PER_TURN,
                "held long enough to reach that body's next turn")
        end,
    },
    -- ------------------------------------------------------------------------------ the trophies
    {
        name = "the Poppy Censer: struck, the foes beside you fall Asleep, then it rests for 3 turns",
        fn = function()
            local c = Fixture.combat(board(), { body(5, 5, { "utility_poppy_censer" }), body(5, 4) },
                { body(5, 6), body(5, 9) })
            local bearer, friend, foe, far = c.units[1], c.units[2], c.units[3], c.units[4]
            strike(c, bearer, 3, foe)
            assert(asleep(foe), "the foe beside you falls Asleep")
            assert(not asleep(friend), "your own line does not")
            assert(not asleep(far), "and a foe further off is untouched")
            Status.remove(c, foe, "status_sleep")
            strike(c, bearer, 3, foe)
            assert(not asleep(foe), "then it rests")
            assert(Combat.onCooldown(bearer, "trait_poppy_censer"), "for its three turns")
        end,
    },
    {
        name = "Baku's Ward: allies within 2 cannot be put to Sleep, and each sleep turned away heals the bearer",
        fn = function()
            local c = Fixture.combat(board(), { body(5, 5, { "utility_bakus_ward" }), body(5, 7), body(5, 9) },
                body(1, 1))
            local bearer, near, far, foe = c.units[1], c.units[2], c.units[3], c.units[4]
            strike(c, bearer, 40, foe)
            local before = hp(bearer)
            Status.apply(c, near, "status_sleep", { applier = foe })
            assert(not asleep(near), "an ally within 2 is not put under")
            assert(hp(bearer) > before, "and the bearer heals for it")
            Status.apply(c, bearer, "status_sleep", { applier = foe })
            assert(not asleep(bearer), "the bearer is within its own ward")
            Status.apply(c, far, "status_sleep", { applier = foe })
            assert(asleep(far), "an ally 4 away sleeps as ever")
        end,
    },
    {
        name = "the Spruce Staff: a turn that attacks nothing raises a root beside you; a turn that strikes does not",
        fn = function()
            local c = Fixture.combat(board(), body(5, 5, { "weapon_spruce_staff" }), body(5, 9))
            local druid, foe = c.units[1], c.units[2]
            Trait.onAnyTurnEnd(c, druid)
            local roots = Dreamers.rootsOf(c, druid)
            assert(#roots == 1 and Combat.unitGap(druid, roots[1]) == 1, "a root rises beside the bearer")
            assert(roots[1].y == 6, "on the side the foe is")

            local c2 = Fixture.combat(board(), body(5, 5, { "weapon_spruce_staff" }), body(5, 6))
            local d2, f2 = c2.units[1], c2.units[2]
            Fixture.openTurn(c2, d2)
            assert(Combat.useItem(c2, d2, Fixture.itemNamed(d2.char, "weapon_spruce_staff"), f2.x, f2.y),
                "the staff strikes, and the strike ends the turn")
            assert(#Dreamers.rootsOf(c2, d2) == 0, "a turn that attacked grows nothing")
            assert(not d2._spruceStruck, "and the next turn starts clean")
            assert(foe.alive)
        end,
    },
}
