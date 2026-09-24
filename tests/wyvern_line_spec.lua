-- Tests for THE WYVERNS (Gluttony's seat floor, 2026-09-23): the line, its encounters, its drops, and the
-- engine seams it needed --
--   * WIND is the ninth element (Combat.ELEMENTS), so an innate `resist = { wind = n }` is legal
--   * AVOID is a stat of its own (Combat.avoid reads flatStat(unit, "avoid")), lent by a status or a trait
--   * a status may lend REACH (`statBonus = { range = n }`, read by Combat.abilityRange)
--   * models/stoop.lua -- the dive, the carry and the drop four items share
-- Each case pins a rule the review approved ("The Wyverns", round 2), on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Stoop = require("models.stoop")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local BODIES = { "character_wyvern", "character_wyvern_alpha", "character_the_highwing" }
local KIT = { "weapon_wind_shear", "utility_tailwind", "ability_take_wing", "utility_lead_the_wind",
              "ability_high_wind", "ability_stoop" }
local DROPS = {
    character_wyvern = { "armor_plummet_cloak", "ability_gale_cut" },
    character_wyvern_alpha = { "utility_tailwind_charm" },
    character_the_highwing = { "ability_skyward", "ability_bear_away" },
}

-- A company body sturdy enough to survive a drop unless a case says otherwise.
local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 200, health or 200
    return spawn
end

local function board(n) return Fixture.new(n or 11, n or 11) end

-- Take wing from `wyvern` at `target`'s tile and land the dive. Returns the dive's own start tile.
local function takeWing(c, wyvern, target)
    openTurn(c, wyvern)
    local ok = Combat.useItem(c, wyvern, itemNamed(wyvern.char, "ability_take_wing"), target.x, target.y)
    assert(ok, "take wing begins its wind-up")
    assert(Status.has(wyvern, "status_aloft"), "and the wyvern is aloft for it")
    return Combat.resolveChannel(c, wyvern)
end

local function gap(a, b) return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the wyvern kit is creature stock, and every drop is a person's unstocked trophy",
        fn = function()
            for _, id in ipairs(KIT) do
                local def = Item.defs[id]
                assert(def, "kit item exists: " .. id)
                assert(def.class == "creature" and def.noSteal, id .. " is unstealable creature kit")
                assert(def.price == nil and def.unlockLevel == nil, id .. " carries no price and no rung")
            end
            for _, bodyId in ipairs(BODIES) do
                local body = Character.defs[bodyId]
                local depth = -1
                for i, id in ipairs(DROPS[bodyId]) do
                    local def = Item.defs[id]
                    assert(def and def.class ~= "creature", "drop is a person's item: " .. id)
                    assert(def.unstocked and def.price == nil, id .. " is seen on the rack and never sold")
                    assert(def.unlockLevel > depth, id .. " sits deeper than the drop above it")
                    depth = def.unlockLevel
                    assert(body.drops[i] == id, bodyId .. " drop " .. i .. " is " .. id)
                end
                local c = Combat.new(board(4), {}, { unit(bodyId, 1, 1) })
                assert(Combat.isFlying(c.units[1]), bodyId .. " flies")
                assert(body.resist.wind and body.resist.wind > 0, bodyId .. " resists the wind it rides")
            end
            assert(Item.defs["armor_plummet_cloak"].class == "skirmisher",
                "the Plummet Cloak went to the Skirmisher on review, not the Poacher")
        end,
    },
    {
        name = "two ordinary fights and an elite, all homed on the wood's seat, and the elite is billed there",
        fn = function()
            for _, id in ipairs({ "encounter_the_wyverns", "encounter_the_flight" }) do
                local enc = Encounter.get(id)
                assert(enc.kind == "combat" and enc.rung == 2, id .. " is ordinary traffic on rung 2")
                assert(enc.condition({ biome = "forest" }) and not enc.condition({ biome = "castle" }),
                    id .. " is locked to the wood")
            end
            local elite = Encounter.get("encounter_the_high_glade")
            assert(elite.kind == "elite" and elite.rung == 2, "the High Glade is an elite on rung 2")
            local billed = false
            for _, sin in ipairs(Descent.SINS) do
                if sin.id == "gluttony" then
                    for _, id in ipairs(sin.elites.spares) do
                        if id == "encounter_the_high_glade" then billed = true end
                    end
                end
            end
            assert(billed, "Gluttony bills the High Glade as a spare")
        end,
    },

    -- ------------------------------------------------------------------------------ the wind
    {
        name = "wind is an element now, and a wyvern's hide turns it",
        fn = function()
            assert(Combat.ELEMENT_TAGS.wind, "wind joins the closed element set")
            assert(Combat.ELEMENTS[#Combat.ELEMENTS] == "wind", "appended last, so the old order replays")
            local c = Combat.new(board(6), { walker(1, 1) }, { unit("character_wyvern", 3, 1) })
            local wyvern = c.units[2]
            local windy = Combat.mitigatedDamage(wyvern, 20, { "physical" })
            local cut = Combat.mitigatedDamage(wyvern, 20, { "physical", "slash", "wind" })
            assert(cut < windy, "slash and wind both come off a wyvern's blow (" .. cut .. " vs " .. windy .. ")")
        end,
    },
    {
        name = "Wind Shear reaches two or three tiles and never an adjacent foe, and backs off after",
        fn = function()
            local c = Combat.new(board(9), { walker(2, 5), walker(5, 7) }, { unit("character_wyvern", 5, 5) })
            local near, far, wyvern = c.units[1], c.units[2], c.units[3]
            near.x, near.y = 4, 5 -- adjacent
            far.x, far.y = 5, 7   -- two tiles
            local shear = itemNamed(wyvern.char, "weapon_wind_shear")
            local seen = {}
            for _, t in ipairs(Combat.abilityTargets(c, wyvern, shear)) do seen[t] = true end
            assert(not seen[near], "an adjacent foe is out of the Shear's reach")
            assert(seen[far], "a foe two tiles off is in it")
            near.x, near.y = 1, 1
            local before = hp(far)
            openTurn(c, wyvern)
            assert(Combat.useItem(c, wyvern, shear, far.x, far.y), "the Shear is thrown")
            assert(hp(far) < before, "and it cuts")
            assert(gap(wyvern, far) == 3, "then the wyvern drifts a tile further off (gap " .. gap(wyvern, far) .. ")")
        end,
    },
    {
        name = "Tailwind is Avoid while nothing stands beside it, and none the moment something does",
        fn = function()
            local c = Combat.new(board(9), { walker(1, 1) }, { unit("character_wyvern", 5, 5) })
            local foe, wyvern = c.units[1], c.units[2]
            local open = Combat.avoid(c, wyvern)
            foe.x, foe.y = 4, 5
            local closed = Combat.avoid(c, wyvern)
            assert(open - closed == 25, "the wind is worth 25 Avoid (" .. open .. " vs " .. closed .. ")")
        end,
    },
    {
        name = "Lead the Wind lends the flight Avoid even up close, and it goes with the alpha",
        fn = function()
            local c = Combat.new(board(9), { walker(4, 5) },
                { unit("character_wyvern", 5, 5), unit("character_wyvern_alpha", 7, 5) })
            local wyvern, alpha = c.units[2], c.units[3]
            local led = Combat.avoid(c, wyvern)
            alpha.alive = false
            local alone = Combat.avoid(c, wyvern)
            assert(led - alone == 15, "a foe beside it, and the alpha still lends 15 (" .. led .. " vs " .. alone .. ")")
            alpha.alive = true
            Status.apply(c, alpha, "status_aloft")
            assert(Combat.avoid(c, wyvern) == alone, "an alpha that has gone up leads nobody")
        end,
    },

    -- ------------------------------------------------------------------------------ taking wing
    {
        name = "Take Wing blows back whoever is beside it and lifts it out of every aim and every blow",
        fn = function()
            local c = Combat.new(board(9), { walker(4, 5), walker(2, 7) }, { unit("character_wyvern", 5, 5) })
            local beside, far, wyvern = c.units[1], c.units[2], c.units[3]
            openTurn(c, wyvern)
            assert(Combat.useItem(c, wyvern, itemNamed(wyvern.char, "ability_take_wing"), far.x, far.y))
            assert(beside.x == 3 and beside.y == 5, "the downdraft blew the adjacent foe a tile back")
            assert(Status.untargetable(wyvern), "aloft, it is off every aim")
            assert(Status.immuneToDamage(wyvern, { "physical", "slash" })
                and Status.immuneToDamage(wyvern, { "magical", "fire" }), "and no blow of either channel reaches it")
        end,
    },
    {
        name = "a Rooted wyvern cannot take wing",
        fn = function()
            local c = Combat.new(board(9), { walker(1, 1) }, { unit("character_wyvern", 5, 5) })
            local wyvern = c.units[2]
            Status.apply(c, wyvern, "status_root")
            local why = Combat.itemBlockReason(wyvern, itemNamed(wyvern.char, "ability_take_wing"))
            assert(why and why.kind == "requirement", "Root holds it to the ground")
        end,
    },

    -- ------------------------------------------------------------------------------ the dive
    {
        name = "a body standing alone is carried off, away from its company, and dropped",
        fn = function()
            local c = Combat.new(board(11), { walker(6, 6), walker(3, 6) }, { unit("character_wyvern", 9, 6) })
            local prey, friend, wyvern = c.units[1], c.units[2], c.units[3]
            local before, apart = hp(prey), gap(prey, friend)
            assert(select(1, takeWing(c, wyvern, prey)), "the dive resolves")
            assert(not Status.has(wyvern, "status_aloft"), "and the wyvern is down")
            assert(gap(prey, friend) > apart, "the prey ends further from its company ("
                .. gap(prey, friend) .. " vs " .. apart .. ")")
            assert(gap(prey, wyvern) == 1, "set down beside the wyvern")
            assert(hp(prey) < before, "and the fall hurts")
        end,
    },
    {
        name = "a friend DIRECTLY beside the mark keeps it on the ground, and the dive does it no harm",
        fn = function()
            local c = Combat.new(board(11), { walker(6, 6), walker(5, 6) }, { unit("character_wyvern", 9, 6) })
            local prey, friend, wyvern = c.units[1], c.units[2], c.units[3]
            local before = hp(prey)
            takeWing(c, wyvern, prey)
            assert(prey.x == 6 and prey.y == 6, "it is not lifted")
            assert(hp(prey) == before, "and every point of the Stoop's harm is on the drop")
            assert(gap(wyvern, prey) == 1, "the wyvern still comes down beside it -- on the ground, and exposed")
            assert(friend.alive, "")
        end,
    },
    {
        name = "a diagonal friend does not count: alone means the four tiles directly beside",
        fn = function()
            local c = Combat.new(board(11), { walker(6, 6), walker(5, 5) }, {})
            assert(Stoop.alone(c, c.units[1]), "a friend on the diagonal leaves the body alone")
            c.units[2].x, c.units[2].y = 6, 5
            assert(not Stoop.alone(c, c.units[1]), "a friend straight above does not")
        end,
    },
    {
        name = "a Rooted body cannot be lifted, and a mark that walked off its tile was dodged",
        fn = function()
            local c = Combat.new(board(11), { walker(6, 6), walker(1, 1) }, { unit("character_wyvern", 9, 6) })
            local prey, other, wyvern = c.units[1], c.units[2], c.units[3]
            Status.apply(c, prey, "status_root")
            assert(not Stoop.liftable(prey), "Root holds the body down")
            local before = hp(prey)
            takeWing(c, wyvern, prey)
            assert(prey.x == 6 and prey.y == 6 and hp(prey) == before, "so the dive lands and takes nothing")

            local c2 = Combat.new(board(11), { walker(6, 6) }, { unit("character_wyvern", 9, 6) })
            local mark, wy = c2.units[1], c2.units[2]
            openTurn(c2, wy)
            assert(Combat.useItem(c2, wy, itemNamed(wy.char, "ability_take_wing"), mark.x, mark.y))
            mark.x, mark.y = 2, 2 -- walked off the painted tile during the wind-up
            local hpBefore = hp(mark)
            Combat.resolveChannel(c2, wy)
            assert(hp(mark) == hpBefore, "the dive finds an empty tile")
            assert(wy.x == 6 and wy.y == 6, "and comes down on it")
            assert(other.alive, "")
        end,
    },
    {
        name = "the drop kills at or under twice the dropper's Damage, and never a boss",
        fn = function()
            local c = Combat.new(board(11), { walker(6, 6), walker(2, 6) }, { unit("character_wyvern", 9, 6) })
            local prey, wyvern = c.units[1], c.units[3]
            local ledge = Stoop.threshold(wyvern)
            assert(ledge == 2 * Combat.flatStat(wyvern, "damage"), "the ledge is the formula")
            prey.char.stats.health.current = ledge
            takeWing(c, wyvern, prey)
            assert(not prey.alive or hp(prey) <= 0, "a body on the ledge does not get up")

            local c2 = Combat.new(board(11), { walker(6, 6), walker(2, 6) }, { unit("character_wyvern", 9, 6) })
            local boss, wy = c2.units[1], c2.units[3]
            boss.char.boss = true
            boss.char.stats.health.current = Stoop.threshold(wy)
            takeWing(c2, wy, boss)
            assert(boss.alive and hp(boss) > 0, "a boss takes the fall and gets up")
        end,
    },

    -- ------------------------------------------------------------------------------ the Highwing
    {
        name = "High Wind is Avoid, reach and footing, and the Stoop is cast only from it and spends it",
        fn = function()
            local c = Combat.new(board(11), { walker(6, 6), walker(2, 6) }, { unit("character_the_highwing", 9, 6) })
            local prey, hw = c.units[1], c.units[3]
            local stoop = itemNamed(hw.char, "ability_stoop")
            assert(Combat.itemBlockReason(hw, stoop), "no Stoop without the High Wind")
            local shear = itemNamed(hw.char, "weapon_wind_shear")
            local reach = Combat.abilityRange(c, hw, shear.activeAbility)
            local avoid = Combat.avoid(c, hw)
            Status.apply(c, hw, "status_high_wind")
            assert(Combat.avoid(c, hw) - avoid == 30, "High Wind is +30 Avoid")
            assert(Combat.abilityRange(c, hw, shear.activeAbility) == reach + 1, "and a tile more reach")
            Status.apply(c, hw, "status_root")
            assert(not Status.has(hw, "status_root"), "and no Root takes")
            assert(not Combat.itemBlockReason(hw, stoop), "the Stoop is open from the wind")
            openTurn(c, hw)
            local before = hp(prey)
            assert(Combat.useItem(c, hw, stoop, prey.x, prey.y), "it stoops")
            assert(not Status.has(hw, "status_high_wind"), "and the wind is spent")
            assert(hp(prey) < before, "the lone mark was carried and dropped")
        end,
    },

    -- ------------------------------------------------------------------------------ the drops
    {
        name = "Skyward lifts a person out of reach and forces the landing beside the mark",
        fn = function()
            local c = Combat.new(board(9), { walker(5, 5, 60) }, { unit("character_wyvern", 7, 5), unit("character_wyvern", 4, 5) })
            local me, mark, beside = c.units[1], c.units[2], c.units[3]
            local sky = Fixture.give(me.char, "ability_skyward")
            openTurn(c, me)
            assert(Combat.useItem(c, me, sky, mark.x, mark.y), "Skyward winds up")
            assert(Status.untargetable(me) and beside.x == 3, "aloft, and the downdraft blew the adjacent foe back")
            local before = hp(mark)
            Combat.resolveChannel(c, me)
            assert(gap(me, mark) == 1, "it comes down beside the mark")
            assert(hp(mark) < before and not Status.has(me, "status_aloft"), "strikes it, and is on the ground")
        end,
    },
    {
        name = "Bear Away lifts a foe off its line and an ally back toward its own",
        fn = function()
            local c = Combat.new(board(11), { walker(6, 6), walker(1, 6) },
                { unit("character_wyvern", 7, 6), unit("character_wyvern", 11, 6) })
            local me, friend, foe, foeFriend = c.units[1], c.units[2], c.units[3], c.units[4]
            local bear = Fixture.give(me.char, "ability_bear_away")
            local apart = gap(foe, foeFriend)
            openTurn(c, me)
            assert(Combat.useItem(c, me, bear, foe.x, foe.y), "the foe is carried")
            assert(gap(foe, foeFriend) > apart, "further from its own side")
            assert(gap(me, foe) == 1, "and set down beside the carrier")

            local c2 = Combat.new(board(11), { walker(8, 6), walker(9, 6), walker(1, 6) },
                { unit("character_wyvern", 10, 6) })
            local carrier, hurt, company = c2.units[1], c2.units[2], c2.units[3]
            local bear2 = Fixture.give(carrier.char, "ability_bear_away")
            local was = gap(hurt, company)
            openTurn(c2, carrier)
            assert(Combat.useItem(c2, carrier, bear2, hurt.x, hurt.y), "the ally is carried")
            assert(gap(hurt, company) < was, "back toward its company (" .. gap(hurt, company) .. " vs " .. was .. ")")
            assert(friend.alive, "")
        end,
    },
    {
        name = "the Plummet Cloak pays a quarter of Damage after a three-tile run, and nothing short of it",
        fn = function()
            local c = Combat.new(board(9), { walker(1, 5) }, { unit("character_wyvern", 8, 5) })
            local me, foe = c.units[1], c.units[2]
            Fixture.give(me.char, "armor_plummet_cloak")
            local Trait = require("models.trait")
            Trait.attach(me, c)
            me.turnStartX, me.turnStartY = 1, 5
            me.x = 3
            assert(Trait.outgoingDamageBonus(c, me, foe, nil, {}) == 0, "two tiles buys nothing")
            me.x = 4
            local want = math.floor(Combat.flatStat(me, "damage") * 0.25 + 0.5)
            assert(Trait.outgoingDamageBonus(c, me, foe, nil, {}) == want, "three tiles buys a quarter")
        end,
    },
}
