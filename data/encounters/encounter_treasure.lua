-- Encounter blueprint. A reward stop rather than a fight: an unguarded cache
-- of loot. Uncommon (low weight) so it feels like a find. See
-- data/encounters/boar.lua for the shape.
return {
    name = "Treasure Chest",
    kind = "treasure",
    weight = 1,
    minPrestige = 1,
    -- What an unauthored chest hands over when opened (states/game.lua grants it via Player.grantItem).
    -- A route may override this per-placement with its own `loot` list -- the flight leg's first chest
    -- gives a specific teaching kit -- but every other treasure now actually pays out instead of being
    -- an empty prop. A stackable so it merges tidily in the stash.
    loot = { "consumable_healing_potion" },
}
