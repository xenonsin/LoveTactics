-- Tests for SLOTH'S COLD, SLICE D ("Sloth's Bestiary", 2026-10-04, five rounds): three bodies of the tundra, their
-- rules, their drops and their two fights.
--
--   the Yuki-onna     Snow-Sleep -- a foe that ends its turn within 3 of her without having moved gains Drowsy (at 3,
--                     Asleep); her Kiss deals double to a sleeper and does not wake it. An oni, as a yokai.
--   the Snow Queen    Splinter -- her Shard-Bolt leaves a body Cold-Hearted: it aims nothing at an ally until fire
--                     strikes it or 3 turns pass. The Glass Palace -- a 3-tile ice wall through the company each
--                     turn, telegraphed a turn ahead; fire melts it.
--   the Mare          Hag-Ridden -- it climbs onto a sleeper: while it rides, blows do not wake the sleeper, and the
--                     sleeper takes the Mare's damage each turn. Strike it and it is thrown off. (Beside the
--                     sleeper, not on its tile: no two bodies share a tile.)
--   the drops         White Silence (elementalist), Splinter of the Mirror (spellbreaker), the Mare's Bridle (assassin).
-- Each case pins a rule the review approved, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Arena = require("models.arena")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Hazard = require("models.hazard")
local Wall = require("models.wall")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local BODIES = { "character_yuki_onna", "character_snow_queen", "character_the_mare" }
local TROPHIES = {
    utility_white_silence = "elementalist",
    ability_splinter_of_the_mirror = "spellbreaker",
    utility_mares_bridle = "assassin",
}
local ORGANS = { "utility_snow_sleep", "utility_glass_palace", "weapon_snow_kiss", "weapon_shard_bolt",
    "weapon_hags_weight" }

local function board() return Fixture.new(9, 9) end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

-- A plain body of the company, wearing `items`, on 100 health.
local function body(x, y, items)
    return unit("character_archer", x, y, { isolate = "bare", items = items, stats = { health = 100 } })
end

local function sides(c)
    local party, enemy = {}, {}
    for _, u in ipairs(c.units) do
        if u.side == "enemy" then enemy[#enemy + 1] = u else party[#party + 1] = u end
    end
    return party, enemy
end

-- End `u`'s turn, having walked or not.
local function endTurn(c, u, walked)
    c.turn = { unit = u, moved = walked or false, moveCost = 0, startX = u.x, startY = u.y }
    Trait.onAnyTurnEnd(c, u)
    c.turn = nil
end

local function asleep(c, u)
    Status.apply(c, u, "status_sleep", {})
    assert(Status.has(u, "status_sleep"), "the fixture puts it to Sleep")
end

local function hit(c, u, n, tags, from)
    Combat.dealFlatDamage(c, u, n, tags or { "physical" }, "test", from, { raw = true })
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the three bodies: an oni snow woman, an elemental queen, an undead mare",
        fn = function()
            local yuki = Character.instantiate("character_yuki_onna")
            assert(yuki.race == "oni" and yuki.kind == "humanoid", "the Yuki-onna is an oni, as a yokai")
            assert(itemNamed(yuki, "utility_oni_blood"), "and the race put the Horn in her grid")
            assert(Character.defs["character_yuki_onna"].tier == 3, "rung 3")
            local queen = Character.defs["character_snow_queen"]
            assert(queen.race == "elemental" and queen.tier == 4 and queen.boss, "the Queen is a tier-4 elemental elite")
            assert(queen.resist.fire < 0, "and fire is her answer")
            local mare = Character.instantiate("character_the_mare")
            assert(mare.race == "undead" and Character.defs["character_the_mare"].tier == 3, "the Mare is undead, rung 3")
        end,
    },
    {
        name = "every trophy is an unstocked find on its body's drop list, on its approved shelf",
        fn = function()
            local dropped = {}
            for _, id in ipairs(BODIES) do
                for _, d in ipairs(Character.defs[id].drops or {}) do dropped[d] = true end
            end
            for id, class in pairs(TROPHIES) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.unstocked and not def.price, id .. " is a trophy: seen on the rack, never sold")
                assert(dropped[id], id .. " is on a body's drop list")
                assert(def.class == class, id .. " sits on the " .. class .. " shelf")
            end
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal, id .. " is a body's own and cannot be taken")
                if def.type == "utility" then assert(def.bound, id .. " is an organ, bound to the body") end
            end
        end,
    },
    {
        name = "the Snow Queen stands on the approach as an elite; Ride by Night is an ordinary fight on the seat",
        fn = function()
            local q = Encounter.get("encounter_sloth_the_snow_queen")
            assert(q and q.kind == "elite" and q.rung == 1, "the Snow Queen: an elite, rung 1")
            local r = Encounter.get("encounter_sloth_ride_by_night")
            assert(r and r.kind == "combat" and r.rung == 2 and r.weight == 3, "Ride by Night: combat, rung 2, weight 3")
            for _, e in ipairs({ q, r }) do
                assert(e.condition({ biome = "tundra" }) and not e.condition({ biome = "cave" }), e.name .. " is the tundra's")
            end
            local function count(list, id)
                local n = 0
                for _, x in ipairs(list) do if x == id then n = n + 1 end end
                return n
            end
            local qs = Arena.resolveComposition(q.composition, { depth = 9 })
            assert(count(qs, "character_snow_queen") == 1 and count(qs, "character_ice_elemental") == 2,
                "the Queen with two Ice Elementals, at the band's centre")
            local rs = Arena.resolveComposition(r.composition, { depth = 10 })
            assert(count(rs, "character_the_mare") == 1 and count(rs, "character_yuki_onna") == 1
                and count(rs, "character_ice_elemental") == 2, "the Mare, the Yuki-onna and two Ice Elementals")
        end,
    },
    -- ------------------------------------------------------------------------------ the Yuki-onna
    {
        name = "Snow-Sleep: a foe that ends its turn within 3 without moving gains Drowsy, and at 3 falls Asleep",
        fn = function()
            local c = Fixture.combat(board(), { body(4, 6), body(1, 1), body(7, 5) },
                { unit("character_yuki_onna", 4, 4) })
            local party = sides(c)
            local still, far, walker = party[1], party[2], party[3]
            endTurn(c, still, false)
            assert(Status.stacksOf(still, "status_drowsy") == 1, "standing still within 3: Drowsy")
            endTurn(c, far, false)
            assert(not Status.has(far, "status_drowsy"), "beyond 3: nothing")
            endTurn(c, walker, true)
            assert(not Status.has(walker, "status_drowsy"), "a body that walked: nothing")
            endTurn(c, still, false)
            endTurn(c, still, false)
            assert(not Status.has(still, "status_drowsy") and Status.has(still, "status_sleep"),
                "the third Drowsy puts it to Sleep")
        end,
    },
    {
        name = "her Kiss deals double to a sleeper, and the sleeper sleeps on",
        fn = function()
            local c = Fixture.combat(board(), { body(4, 5), body(5, 4) }, { unit("character_yuki_onna", 4, 4) })
            local party = sides(c)
            local awake, sleeper = party[1], party[2]
            local yuki = one(c, "character_yuki_onna")
            local kiss = itemNamed(yuki.char, "weapon_snow_kiss")
            Fixture.strike(c, yuki, awake, kiss)
            local plain = 100 - hp(awake)
            asleep(c, sleeper)
            yuki.char.stats.mana.current = yuki.char.stats.mana.max
            Fixture.strike(c, yuki, sleeper, kiss)
            local kissed = 100 - hp(sleeper)
            assert(plain > 0 and kissed >= plain * 2, "double on a sleeper: " .. plain .. " -> " .. kissed)
            assert(Status.has(sleeper, "status_sleep"), "and it does not wake")
        end,
    },
    -- ------------------------------------------------------------------------------ the Snow Queen
    {
        name = "Splinter: a body the Shard-Bolt strikes is Cold-Hearted, aims nothing at an ally, and fire thaws it",
        fn = function()
            local c = Fixture.combat(board(), { body(4, 7, { "ability_heal" }), body(5, 7) },
                { unit("character_snow_queen", 4, 4) })
            local party = sides(c)
            local healer, friend = party[1], party[2]
            local queen = one(c, "character_snow_queen")
            Fixture.strike(c, queen, healer, "weapon_shard_bolt")
            assert(Status.has(healer, "status_cold_hearted"), "the splinter lands")
            assert(Status.get(healer, "status_cold_hearted").remaining <= 15, "for 3 turns")
            hit(c, friend, 20)
            local heal = itemNamed(healer.char, "ability_heal")
            openTurn(c, healer)
            local ok, why = Combat.useItem(c, healer, heal, friend.x, friend.y)
            assert(not ok and why == "cold-hearted", "no heal on an ally: " .. tostring(why))
            for _, t in ipairs(Combat.abilityTargets(c, healer, heal)) do
                assert(t == healer, "and the planner offers no ally either")
            end
            hit(c, healer, 1, { "fire" })
            assert(not Status.has(healer, "status_cold_hearted"), "fire thaws it")
            openTurn(c, healer)
            assert(Combat.useItem(c, healer, heal, friend.x, friend.y), "and the heal goes through again")
        end,
    },
    {
        name = "the Glass Palace: three tiles through the company, a turn ahead, then ice walls; fire melts them",
        fn = function()
            local c = Fixture.combat(board(), { body(2, 5), body(6, 5) }, { unit("character_snow_queen", 4, 1) })
            local queen = one(c, "character_snow_queen")
            endTurn(c, queen, false)
            local marked = {}
            for _, h in ipairs(c.hazards or {}) do
                if h.alive and h.id == "hazard_rising_ice" then marked[#marked + 1] = h end
            end
            assert(#marked == 3, "three tiles marked: " .. #marked)
            for _, h in ipairs(marked) do
                assert(h.x == 4, "an upright line between the two foes, who are spread side to side")
                assert(not Wall.at(c, h.x, h.y), "and nothing has risen yet")
            end
            Hazard.tick(c, 5)
            local walls = 0
            for _, h in ipairs(marked) do if Wall.at(c, h.x, h.y) then walls = walls + 1 end end
            assert(walls == 3, "a turn later, three Ice Walls")
            local pane = marked[1]
            assert(Wall.meltIn(c, { { x = pane.x, y = pane.y } }, { "slash", "physical" }) == 0, "a blade melts nothing")
            assert(Wall.meltIn(c, { { x = pane.x, y = pane.y } }, { "fire", "magical" }) == 1, "fire melts it whole")
            assert(not Wall.at(c, pane.x, pane.y), "and it is gone")
            -- Fire on the telegraph puts it out before it rises.
            endTurn(c, queen, false)
            local h = nil
            for _, z in ipairs(c.hazards or {}) do if z.alive and z.id == "hazard_rising_ice" then h = z break end end
            assert(h, "a fresh telegraph")
            Hazard.douse(c, { { x = h.x, y = h.y } }, { "fire" })
            Hazard.tick(c, 5)
            assert(not Wall.at(c, h.x, h.y), "a doused telegraph raises nothing")
        end,
    },
    -- ------------------------------------------------------------------------------ the Mare
    {
        name = "Hag-Ridden: the Mare climbs onto a sleeper, blows do not wake it, and it takes the Mare's damage",
        fn = function()
            local c = Fixture.combat(board(), { body(4, 5), body(6, 5) }, { unit("character_the_mare", 5, 5) })
            local party = sides(c)
            local sleeper, ally = party[1], party[2]
            local mare = one(c, "character_the_mare")
            asleep(c, sleeper)
            Fixture.strike(c, mare, sleeper, "weapon_hags_weight")
            assert(Status.has(sleeper, "status_hag_ridden") and Status.has(mare, "status_riding"), "it rides")
            assert(Status.has(sleeper, "status_sleep"), "and its own blow did not wake the sleeper")
            assert(Status.get(mare, "status_riding").def.blocksMove, "it sits where it is")
            hit(c, sleeper, 3, { "physical" }, ally)
            assert(Status.has(sleeper, "status_sleep"), "while it rides, an ally's blow does not wake the sleeper")
            local before = hp(sleeper)
            Trait.onAnyTurnStart(c, mare)
            assert(hp(sleeper) < before, "at the top of the Mare's turn the sleeper takes its damage")
            assert(Status.has(sleeper, "status_sleep"), "and sleeps on")
        end,
    },
    {
        name = "Hag-Ridden: strike the Mare and it is thrown off; then a blow wakes the sleeper",
        fn = function()
            local c = Fixture.combat(board(), { body(4, 5), body(6, 5) }, { unit("character_the_mare", 5, 5) })
            local party = sides(c)
            local sleeper, ally = party[1], party[2]
            local mare = one(c, "character_the_mare")
            asleep(c, sleeper)
            Fixture.strike(c, mare, sleeper, "weapon_hags_weight")
            hit(c, mare, 3, { "physical" }, ally)
            assert(not Status.has(sleeper, "status_hag_ridden") and not Status.has(mare, "status_riding"),
                "struck, it is thrown off")
            hit(c, sleeper, 3, { "physical" }, ally)
            assert(not Status.has(sleeper, "status_sleep"), "and the next blow wakes the sleeper")
        end,
    },
    -- ------------------------------------------------------------------------------ the drops
    {
        name = "White Silence carries Snow-Sleep: a foe standing still within 3 of its bearer gains Drowsy",
        fn = function()
            local c = Fixture.combat(board(), body(4, 4, { "utility_white_silence" }),
                { unit("character_archer", 4, 6, { isolate = "bare", stats = { health = 100 } }) })
            local _, enemy = sides(c)
            endTurn(c, enemy[1], false)
            assert(Status.stacksOf(enemy[1], "status_drowsy") == 1, "it gains Drowsy")
        end,
    },
    {
        name = "Splinter of the Mirror leaves a struck foe Cold-Hearted for 2 turns",
        fn = function()
            local c = Fixture.combat(board(), body(4, 4, { "ability_splinter_of_the_mirror" }),
                { unit("character_archer", 4, 5, { isolate = "bare", stats = { health = 100 } }) })
            local party, enemy = sides(c)
            Fixture.strike(c, party[1], enemy[1], "ability_splinter_of_the_mirror")
            local s = Status.get(enemy[1], "status_cold_hearted")
            assert(s and s.remaining <= 10, "Cold-Hearted, for 2 turns")
        end,
    },
    {
        name = "the Mare's Bridle: your blows do not wake a sleeping foe",
        fn = function()
            local c = Fixture.combat(board(), { body(4, 4, { "utility_mares_bridle" }), body(1, 1) },
                { unit("character_archer", 4, 5, { isolate = "bare", stats = { health = 100 } }) })
            local party, enemy = sides(c)
            local foe = enemy[1]
            asleep(c, foe)
            hit(c, foe, 3, { "physical" }, party[1])
            assert(Status.has(foe, "status_sleep"), "the bearer's blow leaves it asleep")
            hit(c, foe, 3, { "physical" }, party[2])
            assert(not Status.has(foe, "status_sleep"), "anybody else's wakes it")
        end,
    },
}
