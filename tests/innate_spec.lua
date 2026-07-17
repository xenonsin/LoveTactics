-- Tests for the innate character traits and their shared engine seams: the Archer's wolf companion,
-- the Knight's Oathward redirect, the Mage's Overchannel, and the Priest's Sanctified Presence aura.
-- Headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Trait = require("models.trait")

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

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

return {
    {
        name = "the Archer fields a free wolf at the opening bell (Wolf Companion)",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_archer", 2, 2) }, { unit("character_bandit", 8, 8) })
            local wolves = 0
            for _, u in ipairs(c.units) do
                if u.alive and u.summoner and u.char.id == "character_wolf_grunt" then wolves = wolves + 1 end
            end
            assert(wolves == 1, "one wolf stands beside the archer at combat start, got " .. wolves)
            -- Free: the archer's mana pool was not reserved against it.
            assert((c.units[1].char.reservations == nil) or (#(c.units[1].char.reservations) == 0),
                "the innate wolf costs no reservation")
        end,
    },
    {
        name = "the Knight's Oathward takes the first hit on an adjacent ally, then goes on cooldown",
        fn = function()
            -- Knight beside a mage; a bandit strikes the mage.
            local c = Combat.new(arena(8, 8),
                { unit("character_knight", 2, 2), unit("character_mage", 3, 2) },
                { unit("character_bandit", 3, 3) })
            local knight, mage, bandit = c.units[1], c.units[2], c.units[3]
            local kHp0, mHp0 = knight.char.stats.health.current, mage.char.stats.health.current

            Combat.dealFlatDamage(c, mage, 12, { "physical" }, "test", bandit)
            assert(mage.char.stats.health.current == mHp0, "the mage takes nothing -- the knight intercepts")
            assert(knight.char.stats.health.current < kHp0, "the knight takes the blow instead")

            -- The intercept is on cooldown now: a second hit reaches the mage.
            local kHp1 = knight.char.stats.health.current
            Combat.dealFlatDamage(c, mage, 12, { "physical" }, "test", bandit)
            assert(mage.char.stats.health.current < mHp0, "the second hit this turn gets through to the mage")
            assert(knight.char.stats.health.current == kHp1, "the knight soaks only the first")
        end,
    },
    {
        name = "the Mage's Overchannel casts through health when mana runs dry",
        fn = function()
            local mage = Character.instantiate("character_mage")
            mage.inventory = {}
            Character.addItem(mage, Item.instantiate("ability_fireball"))          -- cell 1
            Character.addItem(mage, Item.instantiate("utility_overflowing_focus"))     -- the Overchannel relic
            local c = Combat.new(arena(8, 8), { { char = mage, x = 1, y = 1 } }, { unit("character_bandit", 1, 3) })
            local u = c.units[1]
            local fireball = mage.inventory[1]
            local cost = fireball.activeAbility.cost.amount

            mage.stats.mana.current = 3 -- less than the spell's mana cost
            local hp0 = mage.stats.health.current
            -- itemBlockReason must NOT block it (the mage can pay in blood).
            assert(Combat.itemBlockReason(u, fireball) == nil, "an overchannel mage isn't blocked for low mana")

            assert(Combat.useItem(c, u, fireball, 1, 3), "the spell resolves through overchannel")
            assert(mage.stats.mana.current == 0, "mana is drained to empty")
            assert(mage.stats.health.current == hp0 - (cost - 3), "the shortfall was paid in health")
        end,
    },
    {
        name = "the Priest's Sanctified Presence mends an adjacent ally each tick",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_priest", 2, 2), unit("character_knight", 3, 2) },
                { unit("character_bandit", 8, 8) })
            local priest, knight = c.units[1], c.units[2]
            -- Wound the knight so there's room to heal.
            knight.char.stats.health.current = knight.char.stats.health.current - 20
            local hurt = knight.char.stats.health.current

            Combat.regenerate(c, 4) -- four ticks under the priest's presence
            assert(knight.char.stats.health.current > hurt, "the adjacent knight mends under the presence")
            assert(knight.char.stats.health.current == hurt + Combat.SANCTIFY_HEAL * 4,
                "healed by the sanctify rate times the ticks")
        end,
    },
    {
        name = "an item grants the same innate to anyone (traits are items)",
        fn = function()
            -- A knight carrying the Companion Whistle fields a wolf, exactly as the archer does innately.
            local knight = Character.instantiate("character_knight")
            Character.addItem(knight, Item.instantiate("utility_companion_whistle"))
            local c = Combat.new(arena(8, 8), { { char = knight, x = 2, y = 2 } }, { unit("character_bandit", 8, 8) })
            local wolves = 0
            for _, u in ipairs(c.units) do
                if u.alive and u.char.id == "character_wolf_grunt" then wolves = wolves + 1 end
            end
            assert(wolves == 1, "the whistle summons a wolf for its carrier too")
        end,
    },
}
