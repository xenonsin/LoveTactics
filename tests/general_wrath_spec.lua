-- The general of Wrath's two-phase fight (docs/story.md, "The Colosseum"). Ira opens as the sullen
-- human (character_general_wrath) and sheds into her demon body (character_general_wrath_demon)
-- at a health threshold, driven by the phase script on her Unappeased Heart relic
-- (data/items/utility/utility_unappeased_heart.lua -> data/traits/trait_boss_phases.lua ->
-- models/transform.lua). Pure logic, headless -- mirrors tests/demon_champion_spec.lua, which pins the
-- phase system itself; this pins Ira's use of it AND the assassinate-through-transform seam it needs.

local Character = require("models.character")
local Combat = require("models.combat")

local function gridHasItem(char, id)
    for _, item in ipairs(Character.eachItem(char)) do
        if item.id == id then return true end
    end
    return false
end

local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 } end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

local function traitOn(u, id)
    for _, t in ipairs(u.traits or {}) do if t.id == id then return t end end
end

-- A fresh slot-10 board: a durable party body that only ever watches, and Ira on her own.
local function board(objective)
    local c = Combat.new(arena(10, 10, objective),
        { unit("character_rowan", 1, 1) },
        { unit("character_general_wrath", 5, 5) })
    return c, c.units[2]
end

return {
    {
        name = "Ira sheds into her demon body when a survived blow takes her past 40% health",
        fn = function()
            local c, ira = board()
            assert(ira.char.id == "character_general_wrath", "she opens as the human instrument")
            assert(traitOn(ira, "trait_boss_phases"), "the Heart carries the phase trigger")
            assert(traitOn(ira, "trait_wrath_rising"), "and her rising-wrath rule, in phase one")
            local pool = ira.char.stats.health -- the continuous thing a transform must carry, by reference

            -- Sit her just below the 40% line, but land no blow yet: the trigger is a survived WOUND, not
            -- a low bar. onDamaged has not fired, so she is still human.
            pool.current = math.floor(pool.max * 0.39)
            assert(ira.char.id == "character_general_wrath",
                "low health alone does not transform her -- nothing has been dispatched")

            Combat.dealFlatDamage(c, ira, 20, nil, "test")
            assert(ira.alive, "the crossing blow is survivable")
            assert(ira.char.id == "character_general_wrath_demon", "the survived wound sheds her into the demon body")
            assert(ira == c.units[2] and #c.units == 2, "the SAME unit -- a transform adds no body")
            assert(ira.char.stats.health == pool, "the health pool carried across (a transform is not a heal)")

            -- The demon body carries the rage rule NATIVELY (its `traits` field, not a grid relic): after
            -- the swap the trait list is rebuilt from the demon blueprint, and its only trait is the curve.
            assert(traitOn(ira, "trait_wrath_rising"),
                "the demon body carries the rising-wrath rule, so the curve keeps compounding in phase two")
        end,
    },
    {
        name = "bursting her past 40% in one blow skips the transform: onDamaged never fires on a corpse",
        fn = function()
            local c, ira = board()
            -- From full health, one enormous blow. onDamaged fires only on a SURVIVOR, so a killing hit
            -- crosses no threshold -- you never have to face the second form, the same honest reading
            -- every phased boss keeps (see the Hollow Crown).
            Combat.dealFlatDamage(c, ira, 9999, nil, "test")
            assert(not ira.alive, "the killing blow fells her")
            assert(ira.char.id == "character_general_wrath",
                "she died in her human body: the transform never fired")
        end,
    },
    {
        name = "assassinate is matched THROUGH the transform: phasing does not win the fight, killing her does",
        fn = function()
            local c, ira = board({ type = "assassinate", target = "character_general_wrath" })
            assert(Combat.evaluate(c) == nil, "the general still stands -> ongoing")

            -- Phase her. Without the shape-aware assassinate seam this is where the fight would WRONGLY
            -- end: her char.id is now the demon's and no live unit matches the id the quest named.
            local pool = ira.char.stats.health
            pool.current = math.floor(pool.max * 0.39)
            Combat.dealFlatDamage(c, ira, 20, nil, "test")
            assert(ira.char.id == "character_general_wrath_demon", "she has phased")
            assert(Combat.evaluate(c) == nil,
                "the mark is read through her shape's stashed original -- phasing is not a kill")

            -- Kill the demon. Now the mark is gone in whichever body, and the assassinate resolves.
            Combat.dealFlatDamage(c, ira, 9999, nil, "test")
            assert(not ira.alive, "the demon falls")
            assert(Combat.evaluate(c) == "win", "killing her in either body satisfies the assassinate")
        end,
    },
    {
        name = "the demon body carries the Unbound Heart, and through it the rage rule",
        fn = function()
            -- The phase-two relic (utility_unbound_heart) is the demon's echo of the human Heart: it
            -- grants trait_wrath_rising off a grid item (character-level `traits` are never instantiated),
            -- and NOT the phase trigger, so a body that has already transformed does not try to again.
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 1, 1) },
                { unit("character_general_wrath_demon", 4, 4) })
            local demon = c.units[2]
            assert(gridHasItem(demon.char, "utility_unbound_heart"), "the Unbound Heart sits in the demon's grid")
            assert(traitOn(demon, "trait_wrath_rising"), "and it carries the rising-wrath rule to the demon")
            assert(not traitOn(demon, "trait_boss_phases"), "but NOT the phase trigger -- it has already phased")
        end,
    },
    {
        name = "the demon fights with her two phase-two moves, not just the greataxe",
        fn = function()
            -- The kit the governor coming off gives her: her signature (scales with her own missing
            -- health, ability_the_only_hour) and the anti-kite hook (ability_run_you_down), beside the
            -- lifesteal cleave she always carried.
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 1, 1) },
                { unit("character_general_wrath_demon", 4, 4) })
            local demon = c.units[2]
            assert(gridHasItem(demon.char, "weapon_crimson_greataxe"), "she keeps the cleave that sustains her")
            assert(gridHasItem(demon.char, "ability_the_only_hour"), "and gains her signature, missing-health-scaled blow")
            assert(gridHasItem(demon.char, "ability_run_you_down"), "and the hook that fetches a foe who backs off")
        end,
    },
}
