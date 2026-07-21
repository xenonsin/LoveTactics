return {
    -- Enough to afford a rank-0 item from a vendor on the first visit, so the shops are
    -- usable before the first quest is finished.
    gold = 250,
    prestige = 1,
    -- Every character the player owns (unlimited size).
    startingRoster = { "character_knight", "character_mage", "character_archer", "character_priest" }, -- character ids
    -- The active party: a subset of the roster, capped at Player.MAX_PARTY.
    startingParty = { "character_knight", "character_mage", "character_archer", "character_priest" }, -- character ids
    -- Items the player owns that nobody is carrying. The stash is unbounded; move gear between it
    -- and a character's 3x3 grid in the Loadout panel. A pickpocket whose grid is full pockets its
    -- loot in here too. A new game starts with an EMPTY stash -- the first items the player owns are
    -- the ones the prologue's chests hand over, so the Loadout screen is introduced with just that loot.
    startingStash = {}, -- item ids
    -- Forging stock the player starts with, so the Blacksmith is usable before the first quest pays
    -- out materials (see models/material.lua). Enough for a couple of early upgrades.
    startingMaterials = { -- material id -> count
        material_iron_scrap = 6,
        material_steel_ingot = 2,
    },
}
