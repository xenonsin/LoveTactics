-- Tests for holy damage (data/items/weapon/demon_bane.lua): it is routed like physical damage but
-- carries the `holy` tag, so a target with a negative holy resist (demonic flesh) takes extra. No
-- engine change -- Combat.mitigatedDamage has always summed resist, negatives included. Headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

return {
    {
        name = "a negative holy resist makes a holy hit land harder (demonic flesh + Demon Bane)",
        fn = function()
            -- Target carries Demonic Essence (resist { holy = -8 }); zero its defense to isolate.
            local demon = Character.instantiate("bandit")
            demon.inventory = {}
            Character.addItem(demon, Item.instantiate("demonic_essence"))
            demon.stats.defense = 0

            -- A plain target with the same zero defense but NO demonic flesh, to isolate the resist.
            local mortal = Character.instantiate("bandit")
            mortal.inventory = {}
            mortal.stats.defense = 0

            local hero = Character.instantiate("knight")
            hero.inventory = {}
            Character.addItem(hero, Item.instantiate("demon_bane"))

            local c = Combat.new(arena(6, 6), { { char = hero, x = 1, y = 1 } },
                { { char = demon, x = 1, y = 2 }, { char = mortal, x = 2, y = 2 } })
            local u, d, m = c.units[1], c.units[2], c.units[3]
            local sword = hero.inventory[1]

            -- The holy hit on demonic flesh: damage + the wielder's Damage stat, then +8 from the
            -- negative holy resist.
            local ab = sword.activeAbility
            local expected = ab.damage + hero.stats.damage + 8
            local holy = Combat.computeDamage(c, u, d, sword)
            assert(holy == expected,
                "holy hit on a demon deals base + 8 (expected " .. expected .. ", got " .. holy .. ")")

            -- The same blade on ordinary flesh deals 8 less -- proof the bonus rides on the demon's
            -- negative holy resist, not on the weapon.
            local plain = Combat.computeDamage(c, u, m, sword)
            assert(plain == expected - 8, "the same holy blade deals 8 less to a target with no holy resist")
        end,
    },
}
