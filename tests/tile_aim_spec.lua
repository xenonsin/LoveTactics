-- Tests for "an empty swing is a step": Combat.castDoesSomething, the question the battle screen
-- asks to resolve a click made with a TILE-aimed weapon armed (docs/weapons.md, "Aiming a tile is
-- aiming a direction").
--
-- Every spear, axe and greatsword aims a tile because its aimed cell is a FACING for a line or an
-- arc -- which makes every reachable tile a legal aim, so the move band vanishes inside the cast
-- band and the unit cannot take a step without disarming. states/battle.lua breaks the tie by asking
-- what the cast would actually DO: a swing that connects with nothing becomes a walk (as long as the
-- move is unspent), while anything that lands on a body or LAYS something classifies itself as a
-- cast. This sweep pins that classification, and pins that asking it never touches the board.
--
-- Pure logic (no love.graphics), so it runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

-- Put `id` in the actor's first grid cell and hand back the instance, so a test aims a KNOWN weapon
-- rather than whatever the blueprint happened to ship with. Clears the grid: an adjacency aura from a
-- leftover charm would price the swing differently.
local function arm(u, id)
    u.char.inventory = {}
    local item = Item.instantiate(id)
    u.char.inventory[1] = item
    return item
end

return {
    {
        name = "a spear's line aimed at open ground it catches nobody in does nothing",
        fn = function()
            -- The knight at (2,2) with a foe far away at (7,7). Aiming east hits bare earth: the
            -- 2-tile line runs through (3,2) and (4,2), both empty.
            local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 2) }, { unit("character_bandit", 7, 7) })
            local knight = c.units[1]
            local spear = arm(knight, "weapon_iron_spear")

            assert(Combat.castDoesSomething(c, knight, spear, 3, 2) == false,
                "a thrust into empty air connects with nothing -- the click means walk")
        end,
    },
    {
        name = "the same spear aimed at an EMPTY tile whose line catches a foe does something",
        fn = function()
            -- The foe stands on the line's SECOND tile, so the correct aim is the empty cell in
            -- front. This is the case the rule must never eat: the aim is a facing, not a victim.
            local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 2) }, { unit("character_bandit", 4, 2) })
            local knight = c.units[1]
            local spear = arm(knight, "weapon_iron_spear")

            assert(Combat.castDoesSomething(c, knight, spear, 3, 2) == true,
                "the line runs on through (4,2) and skewers the bandit -- that is a swing")
            -- And of course aiming the body itself still swings.
            assert(Combat.castDoesSomething(c, knight, spear, 4, 2) == true,
                "aiming the occupied tile connects too")
        end,
    },
    {
        name = "an axe's 3-wide arc counts a foe standing off the aimed tile",
        fn = function()
            -- The cleave is perpendicular to the facing, so a bandit beside the aimed cell is caught
            -- by a swing aimed at ground it isn't standing on.
            local c = Combat.new(arena(8, 8), { unit("character_fighter", 2, 4) }, { unit("character_bandit", 3, 3) })
            local fighter = c.units[1]
            local axe = arm(fighter, "weapon_iron_axe")

            assert(Combat.castDoesSomething(c, fighter, axe, 3, 4) == true,
                "the arc widens off the facing and catches the bandit at (3,3)")
            assert(Combat.castDoesSomething(c, fighter, axe, 1, 4) == false,
                "the same arc swung the other way catches nobody")
        end,
    },
    {
        name = "abilities that LAY something classify themselves as doing something on bare ground",
        fn = function()
            -- No per-item declaration decides this: the dry run reaches for fx.placeTrap /
            -- fx.placeHazard / fx.summon, and placing IS doing something.
            local c = Combat.new(arena(8, 8), { unit("character_archer", 2, 2) }, { unit("character_bandit", 7, 7) })
            local hunter = c.units[1]

            for _, id in ipairs({
                "ability_bear_trap",     -- fx.placeTrap
                "ability_writ_of_fire",  -- fx.placeHazard, on a tile nobody stands on yet
                "ability_summon_wolf",   -- fx.summon
                "weapon_the_stillness",  -- a WEAPON that lays ground: it always casts
            }) do
                local item = arm(hunter, id)
                assert(Combat.castDoesSomething(c, hunter, item, 4, 4) == true,
                    id .. " places something on empty ground -- it must never resolve as a step")
            end
        end,
    },
    {
        name = "an item with no active ability, or no effect, does nothing",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 2) }, { unit("character_bandit", 7, 7) })
            local knight = c.units[1]

            assert(Combat.castDoesSomething(c, knight, nil, 3, 2) == false, "no item, nothing to do")
            assert(Combat.castDoesSomething(c, knight, { activeAbility = { target = "tile" } }, 3, 2) == false,
                "an ability with no effect does nothing wherever it is aimed")
        end,
    },
    {
        name = "previewAbility reports `mutates` only for a board-touching cast, and stays inert",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_archer", 2, 2) }, { unit("character_bandit", 3, 2) })
            local hunter = c.units[1]
            local bandit = c.units[2]

            -- A pure-damage swing touches units, never the board.
            local spear = arm(hunter, "weapon_iron_spear")
            local hit = Combat.previewAbility(c, hunter, spear, 3, 2)
            assert(#hit.order == 1, "the thrust reports the one body it catches")
            assert(hit.mutates == false, "damage is not a board mutation")

            -- The trap reports no affected unit at all -- `mutates` is the whole signal.
            local trap = arm(hunter, "ability_bear_trap")
            local before = {
                units = #c.units,
                traps = #(c.traps or {}),
                hazards = #(c.hazards or {}),
                hp = bandit.char.stats.health.current,
                stamina = hunter.char.stats.stamina.current,
            }
            local laid = Combat.previewAbility(c, hunter, trap, 4, 4)
            assert(#laid.order == 0, "a trap laid on empty ground affects nobody")
            assert(laid.mutates == true, "...but it does touch the board")

            -- The dry run is a question, not a cast (see the fx contract in models/combat.lua).
            assert(#c.units == before.units, "no unit appeared or left")
            assert(#(c.traps or {}) == before.traps, "no trap was actually laid")
            assert(#(c.hazards or {}) == before.hazards, "no hazard was actually painted")
            assert(bandit.char.stats.health.current == before.hp, "no damage was actually dealt")
            assert(hunter.char.stats.stamina.current == before.stamina, "no cost was actually paid")
        end,
    },
}
