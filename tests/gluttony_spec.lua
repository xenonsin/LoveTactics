-- The Hunter's Lodge line's two rules, read the two ways (docs/story.md, "The Hunter's Lodge": the
-- hunter answers gluttony with temperance). Gula's Ravenous heals her on every blow she lands
-- (data/traits/trait_ravenous.lua); Kaya opens each battle with a wolf at her side and the Wolfsong Horn
-- she roots the ring with (data/traits/trait_wolf_companion.lua, data/items/utility/utility_wolfsong_horn.lua).
-- Headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Trait = require("models.trait")

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

return {
    {
        name = "Ravenous: every blow Gula lands feeds her -- the long trade is her friend",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_bandit"), x = 3, y = 1 } },
                { { char = Character.instantiate("character_general_gluttony"), x = 1, y = 1 } })
            local gula, foe = c.units[2], c.units[1]
            assert(Trait.has(gula, "trait_ravenous"), "Gula carries her rule (off the Maw in her grid)")

            -- Wound her, so a heal has room to land.
            local hp = gula.char.stats.health
            Combat.dealFlatDamage(c, gula, 60, { "physical" }, "test")
            local before = hp.current
            assert(before < hp.max, "she is wounded going in")

            -- She commits a blow against a foe: she feeds on the wound.
            Trait.onCast(c, gula, { tx = foe.x, ty = foe.y })
            assert(hp.current == before + 8, "a landed blow heals her by her rule's amount")

            -- ...but striking nothing (an empty tile) feeds her nothing.
            local mid = hp.current
            Trait.onCast(c, gula, { tx = 6, ty = 6 })
            assert(hp.current == mid, "no target, no meal")
        end,
    },
    {
        name = "Kaya opens with a wolf at her side, and the horn stays silent until it draws blood",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_kaya"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 5, y = 5 } })
            local kaya = c.units[1]

            assert(Trait.has(kaya, "trait_wolf_companion"), "she carries the wolf off her horn")
            assert(kaya.wolfCompanion and kaya.wolfCompanion.alive, "a wolf fields itself at the first bell")

            local horn = kaya.char.inventory[5]
            assert(horn and horn.id == "utility_wolfsong_horn", "the signature sits in the center cell")
            assert(not Combat.unlockMet(kaya, horn, c), "the howl is locked until the wolf has drawn blood")
        end,
    },
}
