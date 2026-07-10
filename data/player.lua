return {
    -- Enough to afford a rank-0 item from a vendor on the first visit, so the shops are
    -- usable before the first quest is finished.
    gold = 250,
    prestige = 1,
    -- Every character the player owns (unlimited size).
    startingRoster = { "knight", "mage", "archer", "priest" }, -- character ids
    -- The active party: a subset of the roster, capped at Player.MAX_PARTY.
    startingParty = { "knight", "mage", "archer", "priest" }, -- character ids
    -- Items the player owns that nobody is carrying. The stash is unbounded; move gear between it
    -- and a character's 3x3 grid in the Loadout panel. A pickpocket whose grid is full pockets its
    -- loot in here too. These are the pieces the starting loadouts have no room for.
    startingStash = { -- item ids
        "boots_of_speed",
        "mace",
        "decoy",
        "ability_pickpocket",
        "ability_haste",
        "ability_push",
        "ability_pull",
        "ability_doppelganger",
        "ability_blink",
    },
    -- Forging stock the player starts with, so the Blacksmith is usable before the first quest pays
    -- out materials (see models/material.lua). Enough for a couple of early upgrades.
    startingMaterials = { -- material id -> count
        iron_scrap = 6,
        steel_ingot = 2,
    },
}
