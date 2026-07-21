-- Tests for the transformation model (models/transform.lua) and the two things built on it:
-- Polymorph (a pig inflicted on a foe) and Wild Shape (a beast a hunter wears, holding a reservation).
-- Pure logic, headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")
local Transform = require("models.transform")

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

-- A character holding exactly `ids`, so a cast can be aimed without the blueprint's own kit in the way.
local function armed(id, ids)
    local char = Character.instantiate(id)
    char.inventory = {}
    for _, itemId in ipairs(ids) do Character.addItem(char, Item.instantiate(itemId)) end
    return char
end

return {
    {
        name = "a transform swaps the body but carries the health pool across, wounds and all",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 4, 4) })
            local knight = c.units[1]
            knight.char.stats.health.current = 43 -- take a wound first

            Transform.apply(c, knight, "character_pig")
            assert(knight.char.id == "character_pig", "the knight is wearing a pig")
            -- The pool is the continuous thing: a pigged knight has a KNIGHT's health, not a pig's.
            -- This is the rule that stops polymorph being an execute.
            assert(knight.char.stats.health.max == 70, "the original's max health came across")
            assert(knight.char.stats.health.current == 43, "and its current, wound included")
            assert(knight.char.stats.movement == 4, "but the pig's own flat stats apply")
        end,
    },
    {
        name = "a pig has no actions at all -- no items, no fists",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 4, 4) })
            local knight = c.units[1]
            Transform.apply(c, knight, "character_pig")

            assert(#Combat.abilityItems(knight.char) == 0, "a pig carries nothing")
            assert(knight.char.unarmed == nil, "and has no fists to fall back on")
            assert(Combat.defaultWeapon(knight.char) == nil, "so it threatens nothing")
            -- The whole point: it keeps its move.
            assert(Combat.moveBudget(knight) > 0, "a pig can still run")
        end,
    },
    {
        name = "reverting restores the original body, keeping the damage taken as a pig",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 4, 4) })
            local knight = c.units[1]
            Transform.apply(c, knight, "character_pig")
            Combat.dealFlatDamage(c, knight, 30, { "physical" }, "test")
            local afterHit = knight.char.stats.health.current

            Transform.revert(c, knight)
            assert(knight.char.id == "character_knight", "the knight is itself again")
            assert(knight.char.stats.health.current == afterHit, "wounds taken as a pig came back with it")
            assert(Combat.defaultWeapon(knight.char) ~= nil, "and it has its sword back")
        end,
    },
    {
        name = "one shape at a time: a pig cannot also become a bear",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 4, 4) })
            local knight = c.units[1]
            assert(Transform.apply(c, knight, "character_pig"), "the first shape takes")
            assert(Transform.apply(c, knight, "character_dire_bear") == nil, "the second is refused")
            assert(knight.char.id == "character_pig", "and it is still a pig")
        end,
    },
    {
        name = "Polymorph's status owns the shape: curing it turns the pig back",
        fn = function()
            local caster = armed("character_mage", { "ability_polymorph" })
            local c = Combat.new(arena(8, 8), { { char = caster, x = 1, y = 1 } }, { unit("character_bandit", 1, 3) })
            local mage, bandit = c.units[1], c.units[2]

            assert(Combat.useItem(c, mage, caster.inventory[1], 1, 3), "the cast resolves")
            assert(bandit.char.id == "character_pig", "the bandit is a pig")
            assert(Status.has(bandit, "status_polymorph"), "and carries the timer that owns the shape")

            -- Cure/Panacea route through Status.cleanse, which fires onExpire on the way out.
            Combat.cleanse(c, bandit)
            assert(not Status.has(bandit, "status_polymorph"), "the spell is broken")
            assert(bandit.char.id == "character_bandit", "and the pig is a bandit again")
        end,
    },
    {
        name = "Polymorph is dispellable: the shape is an illusion",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_priest", 1, 1) }, { unit("character_bandit", 4, 4) })
            local bandit = c.units[2]
            Status.apply(c, bandit, "status_polymorph")
            assert(bandit.char.id == "character_pig", "the bandit is a pig")

            local result = Combat.dispel(c, { { x = 4, y = 4 } })
            assert(result.revealed == 1, "the dispel finds one illusion")
            assert(bandit.char.id == "character_bandit", "and tearing it down reverts the shape")
        end,
    },
    {
        name = "a boss is unmoved by Polymorph",
        fn = function()
            local caster = armed("character_mage", { "ability_polymorph" })
            local c = Combat.new(arena(8, 8), { { char = caster, x = 1, y = 1 } },
                { unit("character_general_wrath", 1, 3) })
            local mage, boss = c.units[1], c.units[2]
            assert(boss.char.boss, "fixture check: the general is a boss")

            Combat.useItem(c, mage, caster.inventory[1], 1, 3)
            assert(boss.char.id ~= "character_pig", "a boss is never turned into livestock")
        end,
    },
    {
        name = "Wild Shape reserves mana for as long as the shape is worn, and reverting frees it",
        fn = function()
            local char = armed("character_archer", { "ability_wild_shape_bear" })
            local c = Combat.new(arena(8, 8), { { char = char, x = 1, y = 1 } }, { unit("character_bandit", 6, 6) })
            local hunter = c.units[1]
            local manaMax = hunter.char.stats.mana.max

            assert(Combat.useItem(c, hunter, char.inventory[1], 1, 1), "the self-cast resolves")
            assert(hunter.char.id == "character_dire_bear", "the hunter is a bear")

            -- The lien must live on the body the unit is NOW wearing, or the ceiling it caps would
            -- quietly come back for the duration of the shape.
            local reserved = Combat.reservedAmount(hunter.char, "mana")
            assert(reserved > 0, "the shape holds a reservation, got " .. reserved)
            assert(Combat.unreservedMax(hunter.char, "mana") == manaMax - reserved,
                "and the mana ceiling is capped by it")

            Status.remove(c, hunter, "status_wild_shape_bear") -- the timer running out
            assert(hunter.char.id == "character_archer", "the bear is an archer again")
            assert(Combat.reservedAmount(hunter.char, "mana") == 0, "and the upkeep is released")
            assert(Combat.unreservedMax(hunter.char, "mana") == manaMax, "the ceiling comes back")
        end,
    },
    {
        name = "a wild-shaped hunter fights with the beast's kit, not its own",
        fn = function()
            local char = armed("character_archer", { "ability_wild_shape_wolf" })
            local c = Combat.new(arena(8, 8), { { char = char, x = 1, y = 1 } }, { unit("character_bandit", 6, 6) })
            local hunter = c.units[1]

            Combat.useItem(c, hunter, char.inventory[1], 1, 1)
            local weapon = Combat.defaultWeapon(hunter.char)
            assert(weapon and weapon.id == "weapon_fangs", "the wolf bites; it does not carry the hunter's bow")
        end,
    },
}
