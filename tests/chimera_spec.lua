-- Tests for THE CHIMERA (Gluttony's seat floor, 2026-09-23): the body, its three mouths, its drops, and
-- the engine seam it needed --
--   * a HEAD: a unit with its own turn, its own health and its own AI that stands on no tile and reads
--     its position through the body it grows from (Combat.spawnHeads / growHead), aimed at only by a
--     single-target blow (Combat.useItemOnHead), broken by being killed, and grown by an ITEM, so a
--     person can wear one too.
-- Each case pins a rule a blueprint's header argues, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Spoils = require("models.spoils")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local KIT = { "weapon_lions_maw", "utility_chimera_goat", "utility_chimera_serpent",
              "utility_eats_what_is_cut", "utility_unfed_mouth", "ability_goats_breath", "ability_coil" }
local DROPS = { "utility_hearth_hunger", "utility_serpent_head", "utility_goat_head" }

-- A board with a chimera on it (anchor 5,5 -> cells 5..6 x 5..6) and the given party.
local function field(party, opts)
    opts = opts or {}
    return Fixture.combat(Fixture.new(12, 12), party,
        { unit("character_chimera", 5, 5, { stats = opts.stats or { health = 400 } }) })
end

local function partsOf(c)
    local body, goat, serpent
    for _, u in ipairs(c.units) do
        if u.char.id == "character_chimera" then body = u
        elseif u.char.id == "character_chimera_goat" then goat = u
        elseif u.char.id == "character_chimera_serpent" then serpent = u end
    end
    return body, goat, serpent
end

local function kill(c, u) Combat.dealFlatDamage(c, u, 99999, { "physical" }, "test", nil, { raw = true }) end

local function firstWeapon(char)
    for i = 1, Character.MAX_INVENTORY do
        local item = char.inventory[i]
        if item and item.type == "weapon" then return item end
    end
end

local function stacks(u, id)
    local s = Status.get(u, id)
    return s and s.magnitude or 0
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the chimera kit is creature stock, and every drop is a person's unstocked trophy",
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
                assert(def.unlockLevel > depth, id .. " sits deeper than the drop above it")
                depth = def.unlockLevel
            end
            local body = Character.defs["character_chimera"]
            for i, id in ipairs(DROPS) do assert(body.drops[i] == id, "drop " .. i .. " is " .. id) end
            assert(Item.defs["utility_hearth_hunger"].class == "battlemage", "the appetite is Battlemage stock")
            assert(Item.defs["utility_serpent_head"].class == "beastmaster"
                and Item.defs["utility_goat_head"].class == "beastmaster", "a worn head is the Beastmaster's")
            assert(Item.defs["utility_serpent_head"].onlyWhenBroken == "character_chimera_serpent"
                and Item.defs["utility_goat_head"].onlyWhenBroken == "character_chimera_goat",
                "each head's piece is earned by breaking that head")
        end,
    },
    {
        -- Promoted from spare to the seat's billed elite on 2026-09-24, when the Sated left that billing to
        -- hold Gluttony's first stair.
        name = "the Scorched Glade is a rung-2 elite of the wood, billed as the seat's elite",
        fn = function()
            local enc = Encounter.get("encounter_the_chimera")
            assert(enc.kind == "elite" and enc.rung == 2, "an elite homed on rung 2")
            assert(enc.condition({ biome = "forest" }) and not enc.condition({ biome = "castle" }),
                "and locked to the wood")
            local billed = false
            for _, sin in ipairs(Descent.SINS) do
                if sin.id == "gluttony" and sin.elites.seat == "encounter_the_chimera" then billed = true end
            end
            assert(billed, "Gluttony bills it as the seat's elite")
        end,
    },

    -- ------------------------------------------------------------------------------ the heads
    {
        name = "two heads grow at the bell, each on the turn order, standing on no tile",
        fn = function()
            local c = field({ unit("character_knight", 1, 1) })
            local body, goat, serpent = partsOf(c)
            assert(body and goat and serpent, "a lion body and two heads")
            assert(goat.headOf == body and serpent.headOf == body, "grown off the body")
            assert(goat.side == body.side and goat.control == "ai", "on its side, driven by its own AI")
            local seen = {}
            for _, u in ipairs(Combat.turnOrder(c)) do seen[u] = true end
            assert(seen[goat] and seen[serpent] and seen[body], "all three ride the timeline")
            assert(goat.x == body.x and goat.y == body.y and goat.w == 2, "a head reads the body's footprint")
            for _, cell in ipairs({ { 5, 5 }, { 6, 5 }, { 5, 6 }, { 6, 6 } }) do
                assert(Combat.unitAt(c, cell[1], cell[2]) == body, "every cell answers with the body")
            end
            for _, u in ipairs(Combat.unitsNear(c, 5, 5, 3)) do
                assert(not u.headOf, "a head is nobody's neighbour")
            end
            assert(Status.blocksMove(goat) and Status.blocksForcedMove(serpent), "and a head never moves")
        end,
    },
    {
        name = "the body moving carries its heads with it, and a head cannot be shoved off",
        fn = function()
            local c = field({ unit("character_knight", 1, 1) })
            local body, goat = partsOf(c)
            body.x, body.y = 8, 8
            assert(goat.x == 8 and goat.y == 8, "the head is wherever the body is")
            goat.x = 1
            assert(goat.x == 8, "and a write to a head's position is dropped")
        end,
    },
    {
        name = "a single-target blow aimed at a head lands on the head and not on the body",
        fn = function()
            -- A sword: a single-target blow. A spear pierces down a line and is thrown at GROUND, so its
            -- aim is ignored and it lands on the body (Combat.useItemOnHead) -- the picker never offers it.
            local c = field({ unit("character_knight", 4, 5,
                { isolate = "bare", items = { "weapon_iron_sword" }, stats = { damage = 40 } }) })
            local knight = c.units[1]
            local body, goat = partsOf(c)
            local bodyHp, goatHp = hp(body), hp(goat)
            openTurn(c, knight)
            local ok, why = Combat.useItemOnHead(c, knight, firstWeapon(knight.char), goat)
            assert(ok, "the aimed swing lands: " .. tostring(why))
            assert(hp(goat) < goatHp, "the goat is wounded")
            assert(hp(body) == bodyHp, "and the body is not")
            assert(c.aimedHead == nil, "the aim is let go after the one cast")
        end,
    },
    {
        name = "an area blast over the body hits the body alone",
        fn = function()
            local c = field({ unit("character_knight", 5, 9) })
            local body, goat, serpent = partsOf(c)
            local g, s, b = hp(goat), hp(serpent), hp(body)
            local fake = { activeAbility = { aoe = { radius = 2 } } }
            local caught = Combat.aoeUnits(c, fake.activeAbility, 5, 5)
            for _, u in ipairs(caught) do assert(not u.headOf, "no head under a blast") end
            assert(#caught == 1 and caught[1] == body, "the body, once")
            assert(hp(goat) == g and hp(serpent) == s and hp(body) == b, "(measured, not dealt)")
        end,
    },
    {
        name = "killing the body takes both heads with it, and nothing is broken",
        fn = function()
            local c = field({ unit("character_knight", 1, 1) })
            local body, goat, serpent = partsOf(c)
            kill(c, body)
            assert(not goat.alive and not serpent.alive, "the heads go with the body")
            assert(not body.char.brokenHeads, "a dismissed head is not a broken one")
        end,
    },
    {
        name = "breaking a head: the body remembers it, and the lion eats it",
        fn = function()
            local c = field({ unit("character_knight", 1, 1) })
            local body, goat, serpent = partsOf(c)
            body.char.stats.health.current = 200
            kill(c, goat)
            assert(not goat.alive and serpent.alive and body.alive, "one head broken, the rest standing")
            assert(body.char.brokenHeads and body.char.brokenHeads["character_chimera_goat"],
                "the break is written on the body")
            assert(hp(body) > 200, "the lion heals on what it cut off")
            assert(Status.has(body, "status_gorged"), "and is Gorged")
        end,
    },

    -- ------------------------------------------------------------------------------ the mouths
    {
        name = "the goat breathes fire across a cone and the lion bites harder on what burns",
        fn = function()
            local c = field({ unit("character_knight", 5, 7, { stats = { health = 500, defense = 0 } }),
                              unit("character_knight", 1, 1, { stats = { health = 500 } }) })
            local near, far = c.units[1], c.units[2]
            local body, goat = partsOf(c)
            local maw = itemNamed(body.char, "weapon_lions_maw")
            local cold = Combat.computeDamage(c, body, near, maw)
            openTurn(c, goat)
            local ok, why = Combat.useItem(c, goat, itemNamed(goat.char, "ability_goats_breath"), 5, 7)
            assert(ok, "the goat breathes: " .. tostring(why))
            assert(Status.has(near, "status_burn"), "the knight in the cone burns")
            assert(not Status.has(far, "status_burn"), "the one outside it does not")
            local hot = Combat.computeDamage(c, body, near, maw)
            assert(hot - cold >= 3, "Lion's Maw bites harder on the burning: " .. cold .. " -> " .. hot)
        end,
    },
    {
        name = "the serpent coils, and the first melee blow on the body is bitten back and poisoned",
        fn = function()
            local c = field({ unit("character_knight", 4, 5,
                { isolate = "bare", items = { "weapon_iron_sword" }, stats = { health = 500 } }) })
            local knight = c.units[1]
            local body, _, serpent = partsOf(c)
            openTurn(c, serpent)
            assert(Combat.useItem(c, serpent, itemNamed(serpent.char, "ability_coil"), serpent.x, serpent.y),
                "the serpent coils")
            assert(Status.has(body, "status_tail_poised"), "the body is poised")
            Fixture.strike(c, knight, body, firstWeapon(knight.char))
            assert(Status.has(knight, "status_poison"), "the striker is bitten and poisoned")
            assert(not Status.has(body, "status_tail_poised"), "which spends the coil")
            Status.remove(c, knight, "status_poison")
            Fixture.strike(c, knight, body, firstWeapon(knight.char))
            assert(not Status.has(knight, "status_poison"), "a second blow is not answered")
        end,
    },
    {
        name = "a broken serpent bites nobody, whatever coil it left",
        fn = function()
            local c = field({ unit("character_knight", 4, 5,
                { isolate = "bare", items = { "weapon_iron_sword" }, stats = { health = 500 } }) })
            local knight = c.units[1]
            local body, _, serpent = partsOf(c)
            openTurn(c, serpent)
            Combat.useItem(c, serpent, itemNamed(serpent.char, "ability_coil"), serpent.x, serpent.y)
            kill(c, serpent)
            Fixture.strike(c, knight, body, firstWeapon(knight.char))
            assert(not Status.has(knight, "status_poison"), "no tail, no bite")
        end,
    },

    -- ------------------------------------------------------------------------------ hunger
    {
        name = "a mouth that waits comes round sooner, and eating clears it",
        fn = function()
            local c = field({ unit("character_knight", 1, 1) })
            local _, goat = partsOf(c)
            local breath = itemNamed(goat.char, "ability_goats_breath")
            local full = Combat.actionSpeed(goat, breath.activeAbility, breath)
            openTurn(c, goat)
            Combat.wait(c, goat)
            assert(stacks(goat, "status_starving") == 1, "a turn with nothing to do: one stack")
            local hungry = Combat.actionSpeed(goat, breath.activeAbility, breath)
            assert(hungry < full, "its next breath comes sooner: " .. full .. " -> " .. hungry)
            for _ = 1, 4 do openTurn(c, goat); Combat.wait(c, goat) end
            assert(stacks(goat, "status_starving") == 3, "capped at three")
            Combat.feedHunger(c, goat, true)
            assert(not Status.has(goat, "status_starving"), "and an action eats it off")
        end,
    },
    {
        name = "a coil laid over an unused one feeds the serpent's hunger",
        fn = function()
            local c = field({ unit("character_knight", 1, 1) })
            local _, _, serpent = partsOf(c)
            local coil = itemNamed(serpent.char, "ability_coil")
            openTurn(c, serpent)
            Combat.useItem(c, serpent, coil, serpent.x, serpent.y)
            assert(stacks(serpent, "status_starving") == 0, "the first coil is not a hungry one")
            openTurn(c, serpent)
            Combat.useItem(c, serpent, coil, serpent.x, serpent.y)
            assert(stacks(serpent, "status_starving") == 1, "a second over an unused first is")
        end,
    },

    -- ------------------------------------------------------------------------------ the drops
    {
        name = "a head's piece enters the draw only when that head was broken",
        fn = function()
            local char = Character.instantiate("character_chimera")
            local function offered(r)
                local ids = {}
                for _, e in ipairs(Spoils.rankCandidates({ { char = char } }, r)) do ids[e.id] = true end
                return ids
            end
            local goatRank = Spoils.depthOf(Item.defs["utility_goat_head"])
            local serpentRank = Spoils.depthOf(Item.defs["utility_serpent_head"])
            assert(not offered(goatRank)["utility_goat_head"], "an unbroken goat pays nothing")
            assert(not offered(serpentRank)["utility_serpent_head"], "nor an unbroken serpent")
            char.brokenHeads = { character_chimera_goat = true }
            assert(offered(goatRank)["utility_goat_head"], "a broken goat puts its piece in the draw")
            assert(not offered(serpentRank)["utility_serpent_head"], "and says nothing for the serpent")
        end,
    },
    {
        name = "a person wearing a Serpent Head grows one of their own, on their side and on its own AI",
        fn = function()
            local knight = unit("character_knight", 2, 2)
            Fixture.give(knight.char, "utility_serpent_head")
            local c = Fixture.combat(Fixture.new(8, 8), { knight }, { unit("character_knight", 7, 7) })
            local wearer = c.units[1]
            local head
            for _, u in ipairs(c.units) do if u.headOf == wearer then head = u end end
            assert(head and head.char.id == "character_chimera_serpent", "a serpent grows on the knight")
            assert(head.side == wearer.side and head.control == "ai", "on the knight's side, its own mind")
            kill(c, wearer)
            assert(not head.alive, "and it goes down with the knight")
        end,
    },
}
