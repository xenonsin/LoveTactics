-- Tests for the Alchemist (The Crucible) content: the aura-charm extensions (power / range /
-- stack-preservation on adjacent consumables), the Acid armor-strip status, the Disarm weapon gate,
-- and the Envenom poison infusion. Pure logic over models/combat.lua + models/status.lua, so headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")

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
local function openTurn(c, u) c.turn = { unit = u, moved = false, moveCost = 0 } end

-- Place items into specific grid cells: `map` is { [slot] = itemId }. Clears the grid first. Slots
-- 4 and 5 are horizontally adjacent in the 3x3 grid, so an aura charm at 4 reaches a cast from 5.
local function equip(char, map)
    char.inventory = {}
    for slot, id in pairs(map) do char.inventory[slot] = Item.instantiate(id) end
end

local function contains(list, u)
    for _, v in ipairs(list) do if v == u then return true end end
    return false
end

return {
    {
        name = "Alchemic Mastery adds its amountBonus to an adjacent consumable's hit (preview and live)",
        fn = function()
            -- Foe two tiles east, so the radius-1 burst never reaches the caster's own tile.
            local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 2) }, { unit("character_bandit", 4, 2) })
            local k, bandit = c.units[1], c.units[2]

            -- No charm beside the bomb: the plain hit.
            equip(k.char, { [5] = "consumable_fire_bomb" })
            local plain = Combat.previewAbility(c, k, k.char.inventory[5], 4, 2)
            local plainDmg = plain.entries[bandit].damage
            assert(plainDmg > 5, "the plain bomb already lands well above the floor, got " .. plainDmg)

            -- Alchemic Mastery (amountBonus 5) in the adjacent cell: exactly +5 on the same hit.
            equip(k.char, { [5] = "consumable_fire_bomb", [4] = "utility_alchemic_mastery" })
            local boosted = Combat.previewAbility(c, k, k.char.inventory[5], 4, 2)
            assert(boosted.entries[bandit].damage == plainDmg + 5,
                "Mastery adds its amountBonus to the preview, got " .. boosted.entries[bandit].damage)

            -- And the live cast matches the boosted preview (the number the player was shown).
            k.char.stats.stamina.current = 99
            openTurn(c, k)
            local hp = bandit.char.stats.health.current
            assert(Combat.useItem(c, k, k.char.inventory[5], 4, 2), "the boosted bomb lands")
            assert(hp - bandit.char.stats.health.current == plainDmg + 5,
                "the live hit dealt the boosted amount")
        end,
    },
    {
        name = "Everflask spares an adjacent consumable's stack; without it the stack is spent",
        fn = function()
            -- Control: a bomb with no Everflask beside it decrements as usual.
            local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 2) }, { unit("character_bandit", 4, 2) })
            local k = c.units[1]
            equip(k.char, { [5] = "consumable_fire_bomb" })
            k.char.inventory[5].quantity = 3
            k.char.stats.stamina.current = 99
            openTurn(c, k)
            assert(Combat.useItem(c, k, k.char.inventory[5], 4, 2), "the plain bomb is thrown")
            assert(k.char.inventory[5].quantity == 2, "a bomb with no Everflask is spent (3 -> 2)")

            -- With an Everflask in the adjacent cell, the same throw leaves the stack untouched.
            local c2 = Combat.new(arena(8, 8), { unit("character_knight", 2, 2) }, { unit("character_bandit", 4, 2) })
            local k2 = c2.units[1]
            equip(k2.char, { [5] = "consumable_fire_bomb", [4] = "utility_everflask" })
            k2.char.inventory[5].quantity = 3
            k2.char.stats.stamina.current = 99
            openTurn(c2, k2)
            assert(Combat.useItem(c2, k2, k2.char.inventory[5], 4, 2), "the Everflask bomb is thrown")
            assert(k2.char.inventory[5].quantity == 3,
                "an Everflask spares the adjacent bomb's stack (stays 3)")
        end,
    },
    {
        name = "Long-Fuse Reagent extends an adjacent consumable's range (bonus + a foe it now reaches)",
        fn = function()
            -- A foe four tiles away: one past the bomb's base range of 3.
            local c = Combat.new(arena(10, 4), { unit("character_knight", 2, 2) }, { unit("character_bandit", 6, 2) })
            local k, bandit = c.units[1], c.units[2]

            equip(k.char, { [5] = "consumable_fire_bomb" })
            assert(Combat.adjacencyRangeBonus(k.char, k.char.inventory[5]) == 0, "no charm -> no bonus")
            assert(not contains(Combat.abilityTargets(c, k, k.char.inventory[5]), bandit),
                "the far foe is out of the plain bomb's reach")

            equip(k.char, { [5] = "consumable_fire_bomb", [4] = "utility_long_fuse_reagent" })
            assert(Combat.adjacencyRangeBonus(k.char, k.char.inventory[5]) == 1,
                "the Reagent grants +1 range to the adjacent bomb")
            assert(contains(Combat.abilityTargets(c, k, k.char.inventory[5]), bandit),
                "the Reagent brings the far foe into reach")
        end,
    },
    {
        name = "Acid strips armor: a hit lands harder while it clings, and Cure/Panacea restores it",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 2) }, { unit("character_bandit", 3, 2) })
            local atk, target = c.units[1], c.units[2]
            atk.char.stats.damage = 20 -- well above the floor, so the whole armor swing is visible
            target.char.stats.defense = 10
            local sword = Item.instantiate("weapon_iron_sword")

            local before = Combat.computeDamage(c, atk, target, sword)
            Status.apply(c, target, "status_acid") -- statBonus defense -6
            local corroded = Combat.computeDamage(c, atk, target, sword)
            assert(corroded == before + 6, "Acid's -6 defense adds 6 to the hit, got "
                .. corroded .. " vs " .. before)

            Combat.cleanse(c, target) -- Panacea / Cure use this same helper
            assert(Combat.computeDamage(c, atk, target, sword) == before,
                "cleansing the Acid restores the armor")
        end,
    },
    {
        name = "Disarmed refuses a crafted weapon but not a potion, an ability, or the bare fists",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 2) }, { unit("character_bandit", 3, 2) })
            local k = c.units[1]
            equip(k.char, { [5] = "weapon_iron_sword", [6] = "consumable_fire_bomb" })
            k.char.stats.stamina.current = 99
            local sword, bomb, fists = k.char.inventory[5], k.char.inventory[6], k.char.unarmed

            assert(Combat.itemBlockReason(k, sword) == nil, "the sword is usable before the disarm")

            Status.apply(c, k, "status_disarmed")
            local blocked = Combat.itemBlockReason(k, sword)
            assert(blocked and blocked.reason == "disarmed", "the crafted weapon is refused while disarmed")
            assert(Combat.itemBlockReason(k, bomb) == nil, "a stamina consumable is untouched by disarm")
            assert(fists and Combat.itemBlockReason(k, fists) == nil,
                "the bare unarmed fallback is exempt: a disarmed unit can still punch")
        end,
    },
    {
        name = "Envenom infuses an adjacent weapon: it gains the poison tag and inflicts Poison on a hit",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 2) }, { unit("character_bandit", 3, 2) })
            local k, bandit = c.units[1], c.units[2]
            equip(k.char, { [5] = "weapon_iron_sword", [4] = "utility_envenom" })
            k.char.stats.stamina.current = 99
            openTurn(c, k)

            assert(Combat.useItem(c, k, k.char.inventory[5], 3, 2), "the envenomed sword strikes")
            assert(Status.get(bandit, "status_poison"), "the struck foe is left Poisoned by the Envenom aura")
        end,
    },
}
