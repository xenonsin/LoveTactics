-- Tests for out-of-combat consumable use (models/player.lua): gathering the party's restorative
-- draughts, gating a use behind a non-full pool, pouring a flask's leveled magnitude into a member,
-- and clearing a spent stash stack. Pure logic (no combat object, no love.graphics), runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Player = require("models.player")

-- A minimal player table: just the two fields the consumable API reads.
local function playerWith(party, stash)
    return { party = party or {}, stash = stash or {} }
end

-- A character with an EMPTY grid: blueprints ship starting gear (a knight carries potions), which would
-- merge into the test's own stacks and muddy what each case is measuring. We add exactly what we mean to.
local function bareChar(id)
    local char = Character.instantiate(id)
    for i = 1, Character.MAX_INVENTORY do char.inventory[i] = nil end
    return char
end

local function wound(char, stat, current)
    char.stats[stat].current = current
end

return {
    {
        name = "partyRestoratives gathers grid + stash draughts and skips non-restoratives",
        fn = function()
            local knight = bareChar("character_knight")
            Character.addItem(knight, Item.instantiate("consumable_healing_potion", 3))
            Character.addItem(knight, Item.instantiate("consumable_smoke_bomb", 1)) -- not a restorative
            local stash = { Item.instantiate("consumable_mana_potion", 2) }
            local entries = Player.partyRestoratives(playerWith({ knight }, stash))

            assert(#entries == 2, "the healing potion (grid) and mana potion (stash), not the bomb")
            assert(entries[1].where == "grid" and entries[1].char == knight, "grid entry names its holder")
            assert(entries[1].item.id == "consumable_healing_potion", "party grids come before the stash")
            assert(entries[2].where == "stash" and entries[2].char == nil, "stash entry has no holder")
        end,
    },
    {
        name = "partyRestoratives excludes a Heal SPELL that only declares healing",
        fn = function()
            local priest = bareChar("character_priest")
            Character.addItem(priest, Item.instantiate("ability_heal")) -- a spell, not a draught
            local entries = Player.partyRestoratives(playerWith({ priest }))
            assert(#entries == 0, "a Heal spell is cast, not drunk -- it is not a restorative draught")
            priest.stats.health.current = 1
            assert(not Player.canUseConsumableOn(priest, Item.instantiate("ability_heal")),
                "canUseConsumableOn refuses a non-consumable even on a wounded target")
        end,
    },
    {
        name = "partyRestoratives skips a depleted (quantity-0) stack",
        fn = function()
            local knight = bareChar("character_knight")
            local potion = Item.instantiate("consumable_healing_potion", 1)
            potion.quantity = 0 -- spent
            Character.addItem(knight, potion)
            assert(#Player.partyRestoratives(playerWith({ knight })) == 0, "an empty stack is out of stock")
        end,
    },
    {
        name = "canUseConsumableOn is false at a full pool, true when wounded",
        fn = function()
            local knight = bareChar("character_knight")
            local potion = Item.instantiate("consumable_healing_potion", 1)
            assert(not Player.canUseConsumableOn(knight, potion), "full HP: a heal would be wasted")
            wound(knight, "health", knight.stats.health.max - 5)
            assert(Player.canUseConsumableOn(knight, potion), "wounded: the heal has somewhere to go")
        end,
    },
    {
        name = "useConsumableOn pours the leveled magnitude, clamps at max, and spends one",
        fn = function()
            local knight = bareChar("character_knight")
            wound(knight, "health", knight.stats.health.max - 5)
            local potion = Item.instantiate("consumable_healing_potion", 2) -- level 0 heals 30
            local restored, stat = Player.useConsumableOn(knight, potion)
            assert(stat == "health", "a healing draught restores health")
            assert(restored == 5, "clamped to the 5 missing, not the full 30")
            assert(knight.stats.health.current == knight.stats.health.max, "topped to full")
            assert(potion.quantity == 1, "one drunk from the stack of two")
        end,
    },
    {
        name = "a mana potion restores mana by its declared amount",
        fn = function()
            local mage = bareChar("character_mage")
            wound(mage, "mana", 0)
            local flask = Item.instantiate("consumable_mana_potion", 1) -- level 0 restores 12
            local restored, stat = Player.useConsumableOn(mage, flask)
            assert(stat == "mana", "a mana draught restores mana")
            assert(restored == 12, "the full 12 landed into an empty pool")
            assert(mage.stats.mana.current == 12, "mana pool filled by the poured amount")
        end,
    },
    {
        name = "consumeRestorative drops an emptied stash stack from the list",
        fn = function()
            local knight = bareChar("character_knight")
            wound(knight, "health", 1)
            local stashPotion = Item.instantiate("consumable_healing_potion", 1)
            local player = playerWith({ knight }, { stashPotion })
            local entry = Player.partyRestoratives(player)[1]
            Player.consumeRestorative(player, entry, knight)
            assert(#player.stash == 0, "the last of a stash stack is removed once spent")
        end,
    },
    {
        name = "consumeRestorative keeps a spent grid stack in its cell (like combat)",
        fn = function()
            local knight = bareChar("character_knight")
            wound(knight, "health", 1)
            local gridPotion = Item.instantiate("consumable_healing_potion", 1)
            Character.addItem(knight, gridPotion)
            local player = playerWith({ knight })
            local entry = Player.partyRestoratives(player)[1]
            Player.consumeRestorative(player, entry, knight)
            assert(gridPotion.quantity == 0, "the grid stack is emptied")
            assert(Character.slotIndex(knight, gridPotion) ~= nil, "but keeps its grid cell for a restock")
        end,
    },
}
