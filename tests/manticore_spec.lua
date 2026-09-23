-- Tests for THE MANTICORE (Gluttony's seat floor, 2026-09-23): the body, its encounter, its quills and
-- the drops that rebuild them, plus the two engine seams it needed --
--   * a status that STACKS by itself (`stacks = N` in Status.apply), which status_quilled is
--   * an active ability's own COOLDOWN (`activeAbility.cooldown`, Combat.castCooldownKey), which was
--     authored on ability_call_the_court and read by nothing until the Tail Volley needed it
-- Each case pins a rule a blueprint's header argues, on a bare board, so it is measured, not described.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed = Fixture.unit, Fixture.openTurn, Fixture.itemNamed

local KIT = { "weapon_three_rows", "ability_tail_volley", "utility_bristle",
              "utility_manticore_wings", "utility_man_eater" }
local DROPS = { "armor_quillhide", "utility_barbed_fletching", "utility_the_bristling" }

local function quills(u)
    local s = Status.get(u, "status_quilled")
    return s and s.magnitude or 0
end

local function volleyOf(u) return itemNamed(u.char, "ability_tail_volley") end

-- A person's spawn carrying `id` in the first grid slot, so its trait is collected when it joins.
local function wearing(charId, x, y, id, opts)
    local spawn = unit(charId, x, y, opts)
    Fixture.give(spawn.char, id)
    return spawn
end

local function firstWeapon(char)
    for i = 1, Character.MAX_INVENTORY do
        local item = char.inventory[i]
        if item and item.type == "weapon" then return item end
    end
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the manticore kit is creature stock, and every drop is a person's unstocked trophy",
        fn = function()
            for _, id in ipairs(KIT) do
                local def = Item.defs[id]
                assert(def, "kit item exists: " .. id)
                assert(def.class == "creature" and def.noSteal, id .. " is unstealable creature kit")
                assert(def.price == nil and def.unlockLevel == nil, id .. " carries no price and no rung")
            end
            local depth = -1
            for _, id in ipairs(DROPS) do
                local def = Item.defs[id]
                assert(def and def.class ~= "creature", "drop is a person's item: " .. id)
                assert(def.unstocked and def.price == nil, id .. " is seen on the rack and never sold")
                -- The list is ordered shallow to deep, which within one body's list IS the rarity.
                assert(def.unlockLevel > depth, id .. " sits deeper than the drop above it")
                depth = def.unlockLevel
            end
            local body = Character.defs["character_manticore"]
            for i, id in ipairs(DROPS) do assert(body.drops[i] == id, "drop " .. i .. " is " .. id) end
            assert(Combat.isFlying(Combat.new(Fixture.new(4, 4), {},
                { unit("character_manticore", 1, 1) }).units[1]), "a manticore flies")
        end,
    },
    {
        name = "the Manticores are ordinary traffic homed on the wood's seat floor",
        fn = function()
            local enc = Encounter.get("encounter_the_manticores")
            assert(enc.kind == "combat" and enc.rung == 2, "an ordinary fight homed on rung 2")
            assert(enc.condition({ biome = "forest" }) and not enc.condition({ biome = "castle" }),
                "and locked to the wood")
        end,
    },

    -- ------------------------------------------------------------------------------ the quills
    {
        name = "Quilled stacks by itself to four, and each stack is two pierce taken",
        fn = function()
            local c = Fixture.combat(Fixture.new(6, 6), { unit("character_knight", 1, 1) },
                { unit("character_manticore", 5, 5) })
            local knight = c.units[1]
            Status.apply(c, knight, "status_quilled")
            assert(quills(knight) == 1, "one quill")
            for _ = 1, 5 do Status.apply(c, knight, "status_quilled") end
            assert(quills(knight) == 4, "capped at four: " .. quills(knight))
            assert(Status.vulnerability(knight, { "pierce" }) == 8,
                "four quills are exactly Vulnerable: Pierce's 8")
            assert(Status.vulnerability(knight, { "slash" }) == 0, "and nothing to an edge")
            Status.cleanse(c, knight)
            assert(quills(knight) == 0, "a Cure pulls every quill")
        end,
    },
    {
        name = "the Tail Volley quills every foe in its 3x3, spares its own, then cools",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 5, 4), unit("character_knight", 6, 4) },
                { unit("character_manticore", 5, 8), unit("character_manticore", 4, 4) })
            local a, b = c.units[1], c.units[2]
            local m, mate = c.units[3], c.units[4]
            local volley = volleyOf(m)
            openTurn(c, m)
            local ok, why = Combat.useItem(c, m, volley, 5, 4)
            assert(ok, "the volley fires: " .. tostring(why))
            assert(quills(a) == 1 and quills(b) == 1, "both knights in the 3x3 are quilled")
            assert(quills(mate) == 0 and mate.char.stats.health.current == mate.char.stats.health.max,
                "its mate standing in the same 3x3 is untouched")
            local blocked = Combat.itemBlockReason(m, volley)
            assert(blocked and blocked.kind == "cooldown", "and the tail is cooling")
            assert(Combat.itemCooldown(m, volley), "which the grid's clock can read")
            Combat.tickCooldowns(c, volley.activeAbility.cooldown)
            assert(not Combat.itemBlockReason(m, volley), "until its cooldown runs out")
        end,
    },
    {
        name = "a quill that misses lodges nothing",
        fn = function()
            Combat.FORCE_HIT = false
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 5, 4, { stats = { luck = 1000 } }) },
                { unit("character_manticore", 5, 8) })
            local knight, m = c.units[1], c.units[2]
            openTurn(c, m)
            assert(Combat.useItem(c, m, volleyOf(m), 5, 4), "the volley is thrown")
            assert(quills(knight) == 0, "and the quill that missed is not in the body")
        end,
    },
    {
        name = "Bristle sprays every 15 damage taken, at foes within 2, and carries the remainder",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 5, 7), unit("character_knight", 5, 1) },
                { unit("character_manticore", 5, 5, { stats = { health = 200 } }) })
            local near, far, m = c.units[1], c.units[2], c.units[3]
            Combat.dealFlatDamage(c, m, 8, { "physical" }, "test", nil, { raw = true })
            assert(quills(near) == 0, "8 is under the threshold")
            Combat.dealFlatDamage(c, m, 8, { "physical" }, "test", nil, { raw = true })
            assert(quills(near) == 1, "the second 8 carries it over: one spray")
            assert(quills(far) == 0, "and a body four tiles off is out of the spray")
            Combat.dealFlatDamage(c, m, 30, { "physical" }, "test", nil, { raw = true })
            assert(quills(near) == 3, "one heavy blow banks two sprays: " .. quills(near))
        end,
    },
    {
        name = "Man-eater eats a foe that falls beside it, and the tail comes back",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { unit("character_knight", 5, 6), unit("character_knight", 5, 1) },
                { unit("character_manticore", 5, 5) })
            local beside, away, m = c.units[1], c.units[2], c.units[3]
            local volley = volleyOf(m)
            Combat.setCooldown(m, Combat.castCooldownKey(volley), 10)
            Combat.dealFlatDamage(c, away, 9999, { "physical" }, "test", nil, { raw = true })
            assert(away.incapacitated, "a body that falls out of reach keeps its window")
            assert(Combat.itemBlockReason(m, volley), "and the tail is still cooling")
            Combat.dealFlatDamage(c, beside, 9999, { "physical" }, "test", nil, { raw = true })
            assert(beside.corpse and not beside.incapacitated, "the body beside it is eaten where it fell")
            assert(not Status.has(beside, "status_downed"), "with no window left on it")
            assert(not Combat.reanimate(c, beside, 0.5), "and nothing revives it this battle")
            assert(not Combat.itemBlockReason(m, volley), "and the volley is ready again")
        end,
    },

    -- ------------------------------------------------------------------------------ the drops
    {
        name = "Quillhide quills whoever strikes its wearer in melee, and nobody else",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { wearing("character_knight", 5, 6, "armor_quillhide", { stats = { health = 300 } }) },
                { unit("character_manticore", 5, 5), unit("character_manticore", 5, 9) })
            local knight, biter, shooter = c.units[1], c.units[2], c.units[3]
            Fixture.strike(c, biter, knight, "weapon_three_rows")
            assert(quills(biter) == 1, "the bite comes away with a quill in it")
            openTurn(c, shooter)
            assert(Combat.useItem(c, shooter, volleyOf(shooter), 5, 6), "a volley from range")
            assert(quills(shooter) == 0, "answers nothing: it was not a melee blow")
        end,
    },
    {
        name = "Barbed Fletching quills whatever its bearer's weapon lands on",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { wearing("character_knight", 5, 6, "utility_barbed_fletching") },
                { unit("character_manticore", 5, 5, { stats = { health = 300 } }) })
            local knight, m = c.units[1], c.units[2]
            local weapon = firstWeapon(knight.char)
            assert(weapon, "the knight carries a weapon")
            local ok = Fixture.strike(c, knight, m, weapon)
            assert(ok, "the knight swings")
            assert(quills(m) == 1, "and the blow leaves a quill")
        end,
    },
    {
        name = "The Bristling is the manticore's rule at reach one",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                { wearing("character_knight", 5, 5, "utility_the_bristling", { stats = { health = 300 } }) },
                { unit("character_manticore", 5, 6), unit("character_manticore", 5, 7) })
            local knight, adjacent, twoOff = c.units[1], c.units[2], c.units[3]
            Combat.dealFlatDamage(c, knight, 15, { "physical" }, "test", nil, { raw = true })
            assert(quills(adjacent) == 1, "the foe beside the bearer is quilled")
            assert(quills(twoOff) == 0, "one two tiles off is not -- the animal reaches 2, a person 1")
        end,
    },
}
