return {
    -- Enough to afford a rank-0 item from a vendor on the first visit, so the shops are
    -- usable before the first quest is finished.
    gold = 250,
    prestige = 1,
    -- Every character the player owns (unlimited size). The party is earned through play, not handed
    -- over up front: a New Game resets this to just the avatar (states/prologue.lua's begin), then Rowan
    -- (character_rowan) is sworn in the prologue and the rest are recruited at slot 2 of each vendor
    -- line. This default is only the non-prologue baseline (Player.reset), kept lean to match. The old
    -- generic Mage/Archer/Priest are retired from the party -- they live on only as enemy/ally/test
    -- stand-ins (data/quests, tests) with no portrait of their own.
    startingRoster = { "character_rowan" }, -- character ids
    -- The active party: a subset of the roster, capped at Player.MAX_PARTY.
    startingParty = { "character_rowan" }, -- character ids
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
