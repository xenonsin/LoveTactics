-- The alchemist's answer to the one pool that does not come back on its own. Mana is the game's
-- scarce resource by design -- stamina regenerates every tick, health is mended by half the priest's
-- shelf, and mana regenerates for nobody at all except the one body carrying an Arcane Reservoir. A
-- mage's whole battle is therefore rationing, and this flask is the only thing on any shelf that
-- sells that ration back.
--
-- Priced and paced accordingly: it pours less than a Healing Potion heals, because what it buys is
-- worth more. `restoreStat` names the pool it fills, which is also what the two drinking reflexes read
-- to recognise it as a mana draught (Combat.restorativeStat) -- so an Alchemist's Reservoir will reach
-- for this flask, and only this one, when a spell outruns its mana.
return {
    name = "Mana Potion",
    description = "Restores mana to an ally.",
    flavor = "Mana in a bottle, which the Arcanum considers an insult and buys anyway.",
    sprite = "assets/items/mana_potion.png",
    type = "consumable",
    tags = { "potion", "restorative" },
    class = "alchemist",
    price = 60,
    repRank = 1,
    activeAbility = {
        target = "ally", -- includes the user (a unit is its own ally)
        support = true,  -- previews green: a draught handed over is never an attack
        range = 1,
        speed = 2,
        consumesItem = true,
        restore = { 12, 13, 14, 15, 17, 18, 19, 20, 22, 23, 24 }, -- the mana returned
        restoreStat = "mana",
        effect = function(fx)
            fx.restore(fx.target, "mana", fx.amount)
        end,
    },
}
