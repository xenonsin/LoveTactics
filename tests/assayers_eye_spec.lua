-- Tests for the Assayer's Eye (data/items/ability/ability_assayers_eye.lua): an alchemist ability that
-- lays a foe's whole kit open to the party for the rest of the fight. It deals no damage and takes
-- nothing -- the payload is the `inventoryRevealed` flag the battle UI reads to draw the peek card.
-- Pure logic, runs headless.

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

local function unit(id, x, y)
    return { char = Character.instantiate(id), x = x, y = y }
end

return {
    {
        name = "Assayer's Eye lays a foe's inventory open to the party",
        fn = function()
            local caster = unit("character_rowan", 3, 4)
            local lens = Item.instantiate("ability_assayers_eye")
            caster.char.inventory[1] = lens
            local c = Combat.new(arena(8, 8), { caster }, { unit("character_bandit", 5, 4) })
            -- Guarantee the mana the cast costs, whatever the knight's pool happens to be.
            local mana = c.units[1].char.stats.mana
            mana.max = math.max(mana.max or 0, 20)
            mana.current = 20
            local foe = c.units[2]

            assert(not Combat.inventoryRevealed(foe), "a fresh foe's kit is hidden")
            local ok = Combat.useItem(c, c.units[1], lens, foe.x, foe.y)
            assert(ok, "the assay resolves")
            assert(Combat.inventoryRevealed(foe), "the foe's kit is now open to the party")
        end,
    },
    {
        name = "the assay deals no damage and takes nothing",
        fn = function()
            local caster = unit("character_rowan", 3, 4)
            local lens = Item.instantiate("ability_assayers_eye")
            caster.char.inventory[1] = lens
            local c = Combat.new(arena(8, 8), { caster }, { unit("character_bandit", 5, 4) })
            c.units[1].char.stats.mana.max = 20
            c.units[1].char.stats.mana.current = 20
            local foe = c.units[2]
            local hpBefore = foe.char.stats.health.current
            local itemsBefore = #Character.eachItem(foe.char)

            local ok, result = Combat.useItem(c, c.units[1], lens, foe.x, foe.y)
            assert(ok, "the assay resolves")
            assert(result.damageDealt == 0, "it deals no damage")
            assert(foe.char.stats.health.current == hpBefore, "the foe loses no health")
            assert(#Character.eachItem(foe.char) == itemsBefore, "the foe loses no items")
        end,
    },
    {
        name = "the tooltip dry-run records the reveal and no damage",
        fn = function()
            local caster = unit("character_rowan", 3, 4)
            local lens = Item.instantiate("ability_assayers_eye")
            local out = Combat.abilityOutput(caster, lens)
            assert(out, "the ability produces a dry-run output")
            assert(out.reveal, "the dry-run records that it reveals a foe's kit")
            assert(out.damage == 0, "the dry-run reports no damage")
        end,
    },
}
