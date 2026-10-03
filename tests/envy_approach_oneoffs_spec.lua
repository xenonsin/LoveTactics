-- Tests for ENVY'S APPROACH ONE-OFFS (slice D of "Envy's Bestiary", reviewed 2026-10-01..03, rounds 1-3): seven
-- families, each its own, on the Ribstone Waste.
--
--   The Evil Eye            at the start of its turn it sours one blessing of the Fairest it can see into Rattled;
--                           it floats
--   Mirage                  four identical bodies, three illusions: one blow fells one, their blows land nothing;
--                           struck, the real one trades places with an illusion once a round; only it is Mired
--   The Patchwork           whoever last struck it is Conjoined to it; the stitch moves to each new attacker
--   Shade                   Unseen beside a wall or ridge, Limned on open sand; its touch Rattles
--   Jackal Weighers         each turn two of the company go on the scale: the lighter is Spared, the heavier
--                           Weighed, and every Weigher strikes it
--   The Green-Eyed Monster  +2 damage for every pair standing side by side; its roar shoves every pair apart
--   Sand-Eels               they go Underground and come up where the Fairest stood, biting whoever is there
--
-- Each case pins a rule the review approved, on a bare board, plus the drops and the fights' rungs.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Envy = require("models.envy_oneoffs")
local Fairest = require("models.fairest")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local BODIES = {
    character_evil_eye = { race = "demon", tier = 2, organ = "utility_the_evil_eye", drop = "utility_nazar", class = "exorcist" },
    character_mirage = { race = "elemental", tier = 3, organ = "utility_which_one_is_real", drop = "ability_mirage_step", class = "ninja" },
    character_patchwork = { race = "undead", tier = 3, organ = "utility_stitched_to_you", drop = "ability_surgeons_thread", class = "apothecary" },
    character_shade = { race = "undead", tier = 2, organ = "utility_cast_by_you", drop = "armor_shade_cloak", class = "assassin" },
    character_jackal_weigher = { race = "beast", tier = 2, organ = "utility_the_weighing", drop = "utility_scale_of_hearts", class = "inquisitor" },
    character_green_eyed_monster = { race = "demon", tier = 3, organ = "utility_mocks_the_meat", drop = "ability_jealous_roar", class = "barbarian" },
    character_sand_eel = { race = "beast", tier = 1, organ = "weapon_eel_surge", drop = "armor_eel_skin_boots", class = "skirmisher" },
}
local OWN = {
    "weapon_baleful_gaze", "weapon_heat_shimmer", "weapon_sutured_arm", "weapon_shade_touch",
    "weapon_weighers_khopesh", "weapon_jealous_claws", "ability_green_eyed_roar",
}
local FIGHTS = {
    encounter_envy_the_evil_eye = 1, encounter_envy_the_patchwork = 1, encounter_envy_the_lee_of_the_ridge = 1,
    encounter_envy_the_weighing = 1, encounter_envy_the_green_eyed_monster = 1, encounter_envy_the_rippling_sand = 1,
    encounter_envy_eyes_in_the_dark = 2,
}

local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 100, health or 100
    return spawn
end

local function board(n, tiles) return Fixture.new(n or 11, n or 11, { tiles = tiles }) end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id and not u.illusory then return u end end
end

local function hit(c, target, amount, attacker)
    return Combat.dealFlatDamage(c, target, amount, { "physical" }, "test", attacker, { raw = true })
end

local MOUNTAIN = { type = "mountain", walkable = false, moveCost = 99, sightCost = 99 }
local function rock(x, y)
    local t = { x = x, y = y }
    for k, v in pairs(MOUNTAIN) do t[k] = v end
    return t
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "seven one-off families, none of them human, each with its organ and its trophy on a real shelf",
        fn = function()
            for id, want in pairs(BODIES) do
                local def = Character.defs[id]
                assert(def, id .. " exists")
                assert(def.race == want.race and def.race ~= "human", id .. " is a " .. want.race)
                assert(def.tier == want.tier, id .. " stands on tier " .. want.tier)
                local c = Character.instantiate(id)
                assert(itemNamed(c, want.organ), id .. " carries " .. want.organ)
                assert(def.drops and def.drops[1] == want.drop, id .. " drops " .. want.drop)
                local drop = Item.defs[want.drop]
                assert(drop.class == want.class, want.drop .. " is " .. want.class .. " stock")
                assert(drop.unstocked and not drop.price, want.drop .. " is a trophy: on the rack, never sold")
                assert(drop.unlockLevel == 11, want.drop .. " sits at the approach's rung")
                local organ = Item.defs[want.organ]
                assert(organ.class == "creature" and organ.noSteal, want.organ .. " is a body's own")
            end
            for _, id in ipairs(OWN) do
                assert(Item.defs[id] and Item.defs[id].class == "creature", id .. " is a body's own")
            end
            assert(Character.defs.character_mirage.boss, "the Mirage is an elite: off the execute and Charm tables")
        end,
    },
    {
        name = "six approach fights and one seat fight stand on the waste, and the Mirage is an approach elite",
        fn = function()
            for id, rung in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e and e.kind == "combat", id .. " is ordinary traffic")
                assert(e.rung == rung, id .. " is homed on rung " .. rung)
                assert(e.weight >= 2 and e.weight <= 5, id .. " weighs 2-5")
                assert(e.condition({ biome = "desert" }) and not e.condition({ biome = "spire" }), id .. " is desert-locked")
            end
            local m = Encounter.get("encounter_envy_the_mirage")
            assert(m.kind == "elite" and m.rung == 1, "the Mirage is an elite, locked to the approach")
            local seat = Encounter.get("encounter_envy_eyes_in_the_dark").composition({ biome = "desert", rung = 2 })
            local has = {}
            for _, id in ipairs(seat) do has[id] = true end
            assert(has.character_evil_eye and has.character_shade, "two both-floors bodies stand on the seat")
        end,
    },
    -- ------------------------------------------------------------------------------ the Evil Eye
    {
        name = "the Evil Eye: at its turn it sours a blessing of the Fairest into Rattled, needs sight, and floats",
        fn = function()
            local c = Fixture.combat(board(), { walker(5, 8), walker(1, 1) }, { unit("character_evil_eye", 5, 2) })
            local fair, plain, eye = c.units[1], c.units[2], one(c, "character_evil_eye")
            Status.apply(c, fair, "status_hasted")
            assert(Fairest.across(c, eye) == fair, "the blessed body is the Fairest")
            assert(Status.has(eye, "status_evil_eye"), "the eye opens at the bell")
            assert(Combat.isFlying(eye), "it floats")
            Status.onTurnStart(c, eye)
            assert(not Status.has(fair, "status_hasted"), "the blessing is soured")
            assert(Status.has(fair, "status_rattled"), "into Rattled")
            assert(not Status.has(plain, "status_rattled"), "and only on the Fairest")

            local c2 = Fixture.combat(board(11, { rock(5, 4), rock(4, 4), rock(6, 4) }), { walker(5, 8) },
                { unit("character_evil_eye", 5, 2) })
            local f2, e2 = c2.units[1], one(c2, "character_evil_eye")
            Status.apply(c2, f2, "status_hasted")
            Status.onTurnStart(c2, e2)
            assert(Status.has(f2, "status_hasted"), "behind a ridge the Fairest keeps its blessing")
        end,
    },
    -- ------------------------------------------------------------------------------ Mirage
    {
        name = "Mirage: four identical bodies; an illusion falls to one blow and its own blows land nothing",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 9, 200), { unit("character_mirage", 5, 5) })
            local foe = c.units[1]
            local mirages = {}
            for _, u in ipairs(c.units) do if u.char.name == "Mirage" then mirages[#mirages + 1] = u end end
            assert(#mirages == 4, "it fights as four bodies, got " .. #mirages)
            local illusion
            for _, u in ipairs(mirages) do if u.illusory then illusion = u end end
            assert(illusion and illusion.fragile, "three of them are illusions, felled by any blow")
            local before = hp(foe)
            assert(hit(c, foe, 30, illusion) == 0 and hp(foe) == before, "an illusion's blow lands nothing")
            hit(c, illusion, 1, foe)
            assert(not illusion.alive, "one blow and it is gone")
        end,
    },
    {
        name = "Mirage: struck, the real one trades places with an illusion once a round, and only it sinks",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 9, 200), { unit("character_mirage", 5, 5) })
            local foe, real = c.units[1], one(c, "character_mirage")
            local x, y = real.x, real.y
            hit(c, real, 5, foe)
            assert(real.x ~= x or real.y ~= y, "struck, it is somewhere else")
            local x2, y2 = real.x, real.y
            hit(c, real, 5, foe)
            assert(real.x == x2 and real.y == y2, "but only once a round")
            Trait.onAnyTurnEnd(c, real)
            hit(c, real, 5, foe)
            assert(real.x ~= x2 or real.y ~= y2, "its own turn re-arms the shimmer")
            local illusion = Envy.illusionsOf(c, real)[1]
            assert(Status.apply(c, illusion, "status_mired") == nil, "an illusion weighs nothing")
            assert(Status.apply(c, real, "status_mired") ~= nil, "the real one sinks")
        end,
    },
    -- ------------------------------------------------------------------------------ the Patchwork
    {
        name = "the Patchwork: whoever last struck it is Conjoined to it, and the stitch moves on",
        fn = function()
            local c = Fixture.combat(board(), { walker(5, 6, 200), walker(4, 5, 200) }, { unit("character_patchwork", 5, 5) })
            local a, b, patch = c.units[1], c.units[2], one(c, "character_patchwork")
            hit(c, patch, 10, a)
            assert(Status.has(a, "status_conjoined"), "the striker is stitched")
            hit(c, patch, 10, b)
            assert(Status.has(b, "status_conjoined") and not Status.has(a, "status_conjoined"),
                "the stitch moves to the new attacker")
            local before = hp(b)
            hit(c, patch, 20, a)
            assert(hp(b) == before - 10, "the stitched body takes half the wound, got " .. (before - hp(b)))
            assert(Status.has(a, "status_conjoined"), "and the stitch moves again")
        end,
    },
    -- ------------------------------------------------------------------------------ Shade
    {
        name = "Shade: Unseen beside a ridge, Limned on open sand, found the moment it is shoved out; its touch Rattles",
        fn = function()
            local c = Fixture.combat(board(11, { rock(6, 5) }), walker(3, 5), { unit("character_shade", 5, 5) })
            local foe, shade = c.units[1], one(c, "character_shade")
            assert(Status.has(shade, "status_invisible"), "beside the ridge it is Unseen")
            Combat.knockback(c, { x = 6, y = 5 }, shade, 1)
            assert(shade.x == 4, "shoved off the rock")
            assert(not Status.has(shade, "status_invisible") and Status.has(shade, "status_limned"),
                "and on open sand it is Limned at once")
            local c2 = Fixture.combat(board(), walker(5, 6), { unit("character_shade", 5, 5) })
            local f2, s2 = c2.units[1], one(c2, "character_shade")
            assert(Status.has(s2, "status_limned"), "it opens Limned on open ground")
            Fixture.strike(c2, s2, f2, "weapon_shade_touch")
            assert(Status.has(f2, "status_rattled"), "its touch leaves the target Rattled")
        end,
    },
    -- ------------------------------------------------------------------------------ the Weighers
    {
        name = "Jackal Weighers: the lighter heart is Spared, the heavier Weighed, and the Weighers go for it",
        fn = function()
            local c = Fixture.combat(board(), { walker(5, 7, 60), walker(6, 6, 120) },
                { unit("character_jackal_weigher", 5, 5), unit("character_jackal_weigher", 9, 9) })
            local light, heavy = c.units[1], c.units[2]
            local w1 = one(c, "character_jackal_weigher")
            assert(Status.has(w1, "status_weighing"), "a Weigher carries the scale")
            Status.onTurnStart(c, w1)
            assert(Status.has(heavy, "status_weighed"), "the heavier heart is Weighed")
            assert(Status.has(light, "status_spared"), "the lighter heart is Spared")
            for _, u in ipairs(c.units) do
                if u.char.id == "character_jackal_weigher" then
                    local plan = Envy.plan(c, u)
                    assert(plan, "every Weigher plans against the scale")
                    if plan.item then
                        assert(plan.tx == heavy.x and plan.ty == heavy.y, "and strikes the heavier")
                    end
                end
            end
        end,
    },
    -- ------------------------------------------------------------------------------ the Green-Eyed Monster
    {
        name = "the Green-Eyed Monster: +2 damage a pair standing side by side, and its roar shoves every pair apart",
        fn = function()
            local c = Fixture.combat(board(), { walker(5, 7), walker(6, 7), walker(2, 2) },
                { unit("character_green_eyed_monster", 5, 4) })
            local a, b, lone, monster = c.units[1], c.units[2], c.units[3], one(c, "character_green_eyed_monster")
            assert(Trait.outgoingDamageBonus(c, monster, lone, nil, {}) == 2, "one pair: +2")
            local plan = Envy.plan(c, monster)
            assert(plan and plan.item and plan.item.id == "ability_green_eyed_roar", "it roars at a pair")
            openTurn(c, monster)
            Combat.useItem(c, monster, plan.item, plan.tx, plan.ty)
            assert(Combat.unitGap(a, b) == 3, "the pair is shoved 2 tiles apart, gap " .. Combat.unitGap(a, b))
            assert(Trait.outgoingDamageBonus(c, monster, lone, nil, {}) == 0, "and nobody stands together")
        end,
    },
    -- ------------------------------------------------------------------------------ Sand-Eels
    {
        name = "Sand-Eels: it dives for the Fairest, and comes up biting whoever stands on that tile",
        fn = function()
            local c = Fixture.combat(board(), { walker(5, 8), walker(2, 5) }, { unit("character_sand_eel", 5, 4) })
            local fair, other, eel = c.units[1], c.units[2], one(c, "character_sand_eel")
            Status.apply(c, fair, "status_hasted")
            local plan = Envy.plan(c, eel)
            assert(plan and plan.item.id == "weapon_eel_surge" and plan.tx == fair.x and plan.ty == fair.y,
                "it aims under the Fairest")
            local ab = Item.defs.weapon_eel_surge.activeAbility
            assert(ab.channelStatus == "status_underground" and ab.windup, "it goes Underground on a turn's tell")
            local before = hp(fair)
            openTurn(c, eel)
            Combat.useItem(c, eel, plan.item, plan.tx, plan.ty)
            assert(Status.has(eel, "status_underground"), "it goes under the sand")
            Combat.resolveChannel(c, eel)
            assert(not Status.has(eel, "status_underground"), "and comes up")
            assert(hp(fair) < before, "the Fairest is bitten")
            assert(hp(other) == 100, "nobody else is")
            assert(Combat.unitGap(eel, fair) <= 2, "the eel is up beside it")
        end,
    },
    -- ------------------------------------------------------------------------------ the trophies
    {
        name = "the Nazar turns aside the first debuff each fight, and only the first",
        fn = function()
            local c = Fixture.combat(board(), unit("character_archer", 5, 5, { isolate = "bare", items = { "utility_nazar" } }),
                walker(5, 7))
            local bearer = c.units[1]
            Status.apply(c, bearer, "status_poison", { duration = 10 })
            assert(not Status.has(bearer, "status_poison"), "the first is turned aside")
            Status.apply(c, bearer, "status_poison", { duration = 10 })
            assert(Status.has(bearer, "status_poison"), "the second lands")
            local c2 = Fixture.combat(board(), unit("character_archer", 5, 5, { isolate = "bare", items = { "utility_nazar", "weapon_iron_sword" } }),
                walker(5, 7))
            local item = Combat.curseItem(c2, c2.units[1])
            assert(item == nil, "a hex is turned aside too")
        end,
    },
    {
        name = "the Scale of Hearts: +4 on a blow into a foe with more current health than the bearer",
        fn = function()
            local c = Fixture.combat(board(), unit("character_archer", 5, 5, { isolate = "bare", items = { "utility_scale_of_hearts" }, stats = { health = 50 } }),
                { walker(5, 7, 100), walker(1, 1, 20) })
            local bearer, full, low = c.units[1], c.units[2], c.units[3]
            assert(Trait.outgoingDamageBonus(c, bearer, full, nil, {}) == 4, "+4 into the fuller foe")
            assert(Trait.outgoingDamageBonus(c, bearer, low, nil, {}) == 0, "nothing into the emptier one")
        end,
    },
    {
        name = "Jealous Roar shoves every foe within 2 two tiles from its nearest ally",
        fn = function()
            local c = Fixture.combat(board(), unit("character_archer", 5, 5, { isolate = "bare", items = { "ability_jealous_roar" } }),
                { walker(5, 7), walker(6, 7) })
            local bearer, a, b = c.units[1], c.units[2], c.units[3]
            Fixture.strike(c, bearer, bearer, "ability_jealous_roar")
            assert(a.x == 3 and a.y == 7, "pushed 2 from its ally, at " .. a.x .. "," .. a.y)
            assert(Combat.unitGap(a, b) >= 3, "the pair is parted")
        end,
    },
    {
        name = "Eel-Skin Boots keep the wearer out of Mired; the Shade Cloak hides it beside a wall",
        fn = function()
            local c = Fixture.combat(board(11, { rock(6, 5) }),
                { unit("character_archer", 5, 5, { isolate = "bare", items = { "armor_shade_cloak" } }),
                  unit("character_archer", 2, 2, { isolate = "bare", items = { "armor_eel_skin_boots" } }) },
                walker(9, 9))
            local cloaked, booted = c.units[1], c.units[2]
            assert(Status.has(cloaked, "status_invisible"), "beside the wall the cloak's wearer is Unseen")
            assert(not Status.has(booted, "status_invisible"), "open ground hides nobody")
            assert(Status.apply(c, booted, "status_mired") == nil, "quicksand does not Mire the boots")
        end,
    },
    {
        name = "Surgeon's Thread stitches two foes into one binding; Mirage Step blinks and leaves an illusion",
        fn = function()
            local c = Fixture.combat(board(), unit("character_archer", 5, 5, { isolate = "bare",
                items = { "ability_surgeons_thread", "ability_mirage_step" }, stats = { mana = 50, stamina = 50 } }),
                { walker(5, 7), walker(6, 7) })
            local bearer, a, b = c.units[1], c.units[2], c.units[3]
            Fixture.strike(c, bearer, a, "ability_surgeons_thread")
            local sa, sb = Status.get(a, "status_conjoined"), Status.get(b, "status_conjoined")
            assert(sa and sb and sa.link and sa.link == sb.link, "both ends share one link")
            openTurn(c, bearer)
            Combat.useItem(c, bearer, itemNamed(bearer.char, "ability_mirage_step"), 2, 5)
            assert(bearer.x == 2 and bearer.y == 5, "the caster blinks")
            local double = Combat.unitAt(c, 5, 5)
            assert(double and double.fragile and double.decoyOf == bearer, "an illusion stands where it was")
        end,
    },
}
