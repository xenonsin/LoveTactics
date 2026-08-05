-- Tests for the LANDING a cast previews for its own caster: an ability that moves the body it is cast
-- from (Shadow Step slips to a tile beside its mark before it cuts) has to report where it would leave
-- you, or the only thing the board can show is the reach it is thrown from. Combat.previewAbility
-- answers with userRestsX/userRestsY, which states/battle.lua paints as the landing ring and weighs the
-- counter preview from. Pure logic, so headless.

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

-- A rogue carrying nothing but the named ability, so no neighbouring charm can colour the cast.
local function soloCaster(id, abilityId, x, y)
    local char = Character.instantiate(id)
    char.inventory = {}
    Character.addItem(char, Item.instantiate(abilityId))
    char.stats.stamina.current = char.stats.stamina.max
    return { char = char, x = x, y = y }
end

return {
    {
        name = "Shadow Step previews the tile it blinks the caster onto -- and lands on that very tile",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { soloCaster("character_rogue", "ability_shadow_step", 1, 4) },
                { unit("character_bandit", 5, 4) })
            local rogue, bandit = c.units[1], c.units[2]
            local step = rogue.char.inventory[1]

            local preview = Combat.previewAbility(c, rogue, step, bandit.x, bandit.y)
            assert(preview, "the blink previews")
            assert(preview.userRestsX and preview.userRestsY, "and reports where it would leave the caster")
            -- Beside the mark, and NOT on top of it.
            assert(math.max(math.abs(preview.userRestsX - bandit.x),
                            math.abs(preview.userRestsY - bandit.y)) == 1,
                "the landing is a tile beside the target")
            assert(Combat.unitAt(c, preview.userRestsX, preview.userRestsY) == nil, "and an open one")

            -- The dry run is still a dry run: the caster has not moved, and it is not enrolled as an
            -- affected unit (an entry for the caster would read as a second body in the blast).
            assert(rogue.x == 1 and rogue.y == 4, "the preview leaves the caster standing where it was")
            assert(#preview.order == 1 and preview.order[1].unit == bandit,
                "only the target is an affected unit")

            -- ...and the live cast puts it exactly where the preview said it would.
            local wantX, wantY = preview.userRestsX, preview.userRestsY
            c.turn = { unit = rogue, moved = false, moveCost = 0 }
            assert(Combat.useItem(c, rogue, step, bandit.x, bandit.y), "the blink resolves")
            assert(rogue.x == wantX and rogue.y == wantY,
                "the caster comes to rest on the previewed tile, got "
                    .. rogue.x .. "," .. rogue.y .. " want " .. wantX .. "," .. wantY)
        end,
    },
    {
        name = "a hemmed-in mark previews no move at all -- the cut still lands from where you stood",
        fn = function()
            -- Every neighbour of (5,5) occupied, so Combat.openTileNear finds nowhere to put the caster.
            local foes = { unit("character_bandit", 5, 5) }
            for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 },
                                 { 1, -1 }, { 1, 1 }, { -1, 1 }, { -1, -1 } }) do
                foes[#foes + 1] = unit("character_bandit", 5 + d[1], 5 + d[2])
            end
            local c = Combat.new(arena(8, 8),
                { soloCaster("character_rogue", "ability_shadow_step", 1, 1) }, foes)
            local rogue = c.units[1]
            local bandit = Combat.unitAt(c, 5, 5)

            local preview = Combat.previewAbility(c, rogue, rogue.char.inventory[1], 5, 5)
            assert(preview, "the cast still previews")
            assert(preview.userRestsX == nil, "but reports no landing -- there is nowhere to slip to")
            local entry = preview.entries[bandit]
            assert(entry and entry.damage > 0, "and the strike still lands on the mark")
        end,
    },
    {
        name = "a cast that moves nobody reports no landing",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_knight", 2, 2) }, { unit("character_bandit", 3, 2) })
            local knight, bandit = c.units[1], c.units[2]
            local sword
            for _, it in ipairs(knight.char.inventory) do
                if it.activeAbility and it.type == "weapon" then sword = it break end
            end
            assert(sword, "the knight carries a weapon to swing")

            local preview = Combat.previewAbility(c, knight, sword, bandit.x, bandit.y)
            assert(preview, "the swing previews")
            assert(preview.userRestsX == nil, "an ordinary blow leaves the swinger where it stands")
        end,
    },
}
