-- Tests for THE BLOOD COUNTESS (Wrath's seat elite, approved over rounds 2-3 of "The Vampires of Wrath",
-- 2026-09-27): the basin and the bath (models/basin.lua), her shoving hand, and her two drops.
--
--   the fill      every point of Bleed damage taken anywhere, either side, runs into the basin; standing still
--                 fills nothing
--   the bath      a full basin marks her Bath Drawn; at the top of her next turn she heals to full and is Bathed
--                 (+2 Speed, +20% Damage), to two baths; the basin empties
--   the answer    a broken basin fills nothing and calls off a bath already drawn
--   her hand      opens a vein, then shoves two -- so the first wound bleeds straight into the basin
--   the drops     the Waltz (a swap that bleeds a bleeding foe per tile) and the Iron Maiden (melee attackers Bleed)

local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Arena = require("models.arena")
local Character = require("models.character")
local Item = require("models.item")
local Status = require("models.status")
local Basin = require("models.basin")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local function board(n) return Fixture.new(n or 11, n or 11) end

-- A living company body with a sword, on a fixed health pool.
local function swordsman(x, y, health, items)
    local list = { "weapon_iron_sword" }
    for _, id in ipairs(items or {}) do list[#list + 1] = id end
    return unit("character_archer", x, y, { isolate = "bare", items = list, stats = { health = health or 300 } })
end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function rested(u)
    local st = u.char.stats.stamina
    if type(st) == "table" then st.max, st.current = 99, 99 end
end

local function kill(c, victim)
    Combat.dealFlatDamage(c, victim, 9999, { "physical" }, "test", nil, { raw = true })
end

-- The Countess and her basin (seated in a corner; the basin moves itself to the middle), plus `extra` enemies.
local function court(party, extra)
    local enemies = { unit("character_the_blood_countess", 10, 1), unit("character_blood_basin", 1, 10) }
    for _, e in ipairs(extra or {}) do enemies[#enemies + 1] = e end
    local c = Fixture.combat(board(), party or swordsman(2, 2), enemies)
    return c, one(c, "character_the_blood_countess"), one(c, "character_blood_basin")
end

-- Fill `basin` to the brim in one pour (as if 45 points of Bleed had been taken somewhere).
local function brim(c) Basin.onBleed(c, nil, Basin.CAPACITY) end

return {
    -- ---------------------------------------------------------------------------------------------- the pieces
    {
        name = "the Countess is a tier-3 human duelist and a vampire; the basin is a 2x2 timeless object",
        fn = function()
            local def = Character.defs["character_the_blood_countess"]
            assert(def.tier == 3 and def.race == "human" and def.discipline == "duelist", "a human duelist elite")
            assert(Character.isVampire(Character.instantiate("character_the_blood_countess")), "and a vampire")
            local b = Character.defs["character_blood_basin"]
            assert(b.race == "object" and b.timeless and b.scaling == false, "the basin is a prop outside the clock")
            assert(b.footprint and b.footprint.w == 2 and b.footprint.h == 2, "two tiles by two")
            assert(Item.defs["utility_blood_basin"] and Item.defs["utility_the_bath"]
                and Item.defs["weapon_countess_hand"], "their organs load")
        end,
    },
    {
        name = "the basin stands in the middle of the board, wherever the roll seated it",
        fn = function()
            local _, _, basin = court()
            assert(basin.x == 5 and basin.y == 5, "centred on an 11x11 board: (5,5)-(6,6), got "
                .. basin.x .. "," .. basin.y)
        end,
    },
    {
        name = "the Blood Countess is Wrath's spare elite on the seat, with her basin, ghouls and bats",
        fn = function()
            local e = Encounter.get("encounter_wrath_the_blood_countess")
            assert(e and e.kind == "elite" and e.rung == 2, "an elite on rung 2 (floor eight)")
            assert(e.condition({ biome = "volcanic" }) and not e.condition({ biome = "cave" }), "on the flows")
            local wrath
            for _, s in ipairs(Descent.SINS) do if s.id == "wrath" then wrath = s end end
            local spares = {}
            for _, id in ipairs(wrath.elites.spares) do spares[id] = true end
            assert(spares.encounter_wrath_the_blood_countess, "one of Wrath's spares")
            local seated = Arena.clampComposition(Arena.resolveComposition(e.composition, { depth = 8 }),
                Arena.enemyCap({ encounterKind = "elite", encounterCap = e.enemyCap }))
            local n = {}
            for _, id in ipairs(seated) do n[id] = (n[id] or 0) + 1 end
            assert(n.character_the_blood_countess == 1 and n.character_blood_basin == 1, "the Countess and her basin")
            assert(n.character_blood_ghoul == 2 and (n.character_familiar or 0) >= 2, "two ghouls and her bats")
        end,
    },
    -- ---------------------------------------------------------------------------------------------- the fill
    {
        name = "every point of Bleed damage taken anywhere fills the basin; standing still fills nothing",
        fn = function()
            local c, _, basin = court(swordsman(2, 2), { unit("character_blood_ghoul", 9, 9) })
            local foe, ghoul = c.units[1], one(c, "character_blood_ghoul")
            assert(Basin.level(basin) == 0, "it starts dry")
            Status.apply(c, foe, "status_bleed")
            assert(Basin.level(basin) == 0, "a wound that is not walked on spills nothing")
            Status.onEnterTile(c, foe, "walk")
            assert(Basin.level(basin) == 3, "a company body's step fills it by the tick (3)")
            Status.apply(c, ghoul, "status_bleed")
            Status.onEnterTile(c, ghoul, "walk")
            assert(Basin.level(basin) == 6, "and so does her own side's -- anywhere means anywhere")
            Combat.dealFlatDamage(c, foe, 5, { "physical" }, "test", nil, { raw = true })
            assert(Basin.level(basin) == 6, "a blow that is not Bleed fills nothing")
            assert(Status.get(basin, Basin.FILL).def.badgeCount, "and the badge prints the count")
        end,
    },
    -- ---------------------------------------------------------------------------------------------- the bath
    {
        name = "a full basin draws the bath: next turn she heals to full, +2 Speed and +20% Damage, and it empties",
        fn = function()
            local c, countess, basin = court()
            local max = countess.char.stats.health.max
            countess.char.stats.health.current = 30
            local speed, damage = Combat.flatStat(countess, "speed"), Combat.flatStat(countess, "damage")
            brim(c)
            assert(Basin.isFull(basin), "45 points and it is full")
            assert(Status.has(countess, Basin.DRAWN), "she is marked Bath Drawn")
            assert(hp(countess) == 30, "and nothing happens until her turn")
            Status.onTurnStart(c, countess)
            assert(hp(countess) == max, "she bathes: healed to full, Grave-Cold and all")
            assert(Combat.flatStat(countess, "speed") == speed + 2, "+2 Speed")
            local per = math.max(1, math.floor(damage * 0.20 + 0.5))
            assert(Combat.flatStat(countess, "damage") == damage + per, "+20% of her own Damage")
            assert(Basin.level(basin) == 0 and not Status.has(countess, Basin.DRAWN), "the basin runs dry")
            -- It fills again, and the second bath stacks.
            brim(c)
            Status.onTurnStart(c, countess)
            assert(Combat.flatStat(countess, "speed") == speed + 4, "a second bath: +4 Speed")
            assert(Combat.flatStat(countess, "damage") == damage + 2 * per, "and +40% Damage")
            -- The third heals her and adds nothing: Bathed stops at two.
            countess.char.stats.health.current = 30
            brim(c)
            Status.onTurnStart(c, countess)
            assert(hp(countess) == max, "a third bath still heals her to full")
            assert(Combat.flatStat(countess, "speed") == speed + 4, "but Bathed stops at two")
            assert(Status.stacksOf(countess, Basin.BATHED) == Basin.MAX_BATHS, "two stacks")
        end,
    },
    {
        name = "breaking the basin stops it: a bath already drawn is called off, and Bleed fills nothing more",
        fn = function()
            local c, countess, basin = court(swordsman(2, 2))
            countess.char.stats.health.current = 30
            brim(c)
            assert(Status.has(countess, Basin.DRAWN), "the bath is drawn")
            kill(c, basin)
            assert(not basin.alive, "the basin breaks")
            Status.onTurnStart(c, countess)
            assert(hp(countess) == 30 and not Status.has(countess, Basin.BATHED), "and there is no bath")
            assert(not Status.has(countess, Basin.DRAWN), "the mark is lifted")
            local foe = c.units[1]
            Status.apply(c, foe, "status_bleed")
            Status.onEnterTile(c, foe, "walk")
            assert(#Basin.basins(c) == 0 and not Status.has(countess, Basin.DRAWN), "nothing is filling now")
        end,
    },
    {
        name = "with nobody left to bathe in it, the basin goes with them",
        fn = function()
            local c, countess, basin = court()
            kill(c, countess)
            assert(not basin.alive, "the Countess falls, and her basin with her")
        end,
    },
    -- ---------------------------------------------------------------------------------------------- her hand
    {
        name = "her strike opens a vein and shoves two tiles, and the shove bleeds into the basin",
        fn = function()
            local c, countess, basin = court(swordsman(3, 9))
            local foe = c.units[1]
            countess.x, countess.y = 2, 9
            rested(countess)
            assert(Fixture.strike(c, countess, foe, "weapon_countess_hand"), "the blow lands")
            assert(foe.x == 5 and foe.y == 9, "shoved two tiles, to (5,9); got " .. foe.x .. "," .. foe.y)
            local bleed = Status.get(foe, "status_bleed")
            assert(bleed and bleed.opener == countess, "bleeding, a wound she opened")
            assert(Basin.level(basin) == 6, "the two tiles it was thrown bled 6 into the basin")
        end,
    },
    -- ---------------------------------------------------------------------------------------------- the drops
    {
        name = "the Waltz trades places with a foe within 3; a bleeding one takes its Bleed for every tile",
        fn = function()
            local c = Fixture.combat(board(), swordsman(2, 2, 300, { "ability_the_waltz" }),
                { unit("character_blood_ghoul", 2, 5, { stats = { health = 200 } }) })
            local me, foe = c.units[1], c.units[2]
            rested(me)
            Status.apply(c, foe, "status_bleed", { applier = me })
            local before = hp(foe)
            openTurn(c, me)
            assert(Combat.useItem(c, me, itemNamed(me.char, "ability_the_waltz"), foe.x, foe.y), "the Waltz lands")
            assert(me.x == 2 and me.y == 5 and foe.x == 2 and foe.y == 2, "they trade tiles")
            assert(before - hp(foe) == 9, "three tiles of the swap, 3 Bleed each: 9; got " .. (before - hp(foe)))
            -- A foe that is not bleeding trades places and loses nothing.
            local c2 = Fixture.combat(board(), swordsman(2, 2, 300, { "ability_the_waltz" }),
                { unit("character_blood_ghoul", 4, 3, { stats = { health = 200 } }) })
            local me2, clean = c2.units[1], c2.units[2]
            rested(me2)
            before = hp(clean)
            openTurn(c2, me2)
            assert(Combat.useItem(c2, me2, itemNamed(me2.char, "ability_the_waltz"), clean.x, clean.y))
            assert(me2.x == 4 and clean.x == 2 and hp(clean) == before, "a clean swap costs nothing")
            -- Past 3 is past the dance.
            local c3 = Fixture.combat(board(), swordsman(2, 2, 300, { "ability_the_waltz" }),
                { unit("character_blood_ghoul", 2, 7) })
            local me3 = c3.units[1]
            rested(me3)
            openTurn(c3, me3)
            assert(not Combat.useItem(c3, me3, itemNamed(me3.char, "ability_the_waltz"), 2, 7), "five tiles is too far")
        end,
    },
    {
        name = "Iron Maiden: a foe that hits you in melee Bleeds, and the wound is yours",
        fn = function()
            local c = Fixture.combat(board(), swordsman(5, 6, 300, { "armor_iron_maiden" }),
                { unit("character_blood_ghoul", 5, 5) })
            local wearer, ghoul = c.units[1], c.units[2]
            rested(ghoul)
            assert(Fixture.strike(c, ghoul, wearer, "weapon_iron_sword"), "the ghoul strikes")
            local bleed = Status.get(ghoul, "status_bleed")
            assert(bleed and bleed.opener == wearer, "and bleeds on the spikes, a wound the wearer opened")
        end,
    },
    {
        name = "her drops are unstocked trophies on floor eight's rung: the Waltz a Duelist's, the Maiden a Knight's",
        fn = function()
            local drops = Character.defs["character_the_blood_countess"].drops
            assert(drops[1] == "ability_the_waltz" and drops[2] == "armor_iron_maiden", "she drops both")
            local w, m = Item.defs["ability_the_waltz"], Item.defs["armor_iron_maiden"]
            assert(w.unstocked and not w.price and w.unlockLevel == 8 and w.class == "duelist", "the Waltz")
            assert(m.unstocked and not m.price and m.unlockLevel == 8 and m.class == "knight", "the Iron Maiden")
        end,
    },
}
