return {
    -- Enough to afford a rank-0 item from a vendor on the first visit, so the shops are
    -- usable before the first quest is finished.
    gold = 250,
    prestige = 1,
    -- Every character the player owns, which is also the whole marching company -- everyone comes to
    -- the quest, and which of them take the field is chosen per battle in the deployment phase (see
    -- docs/deployment.md). Unlimited size. The company is earned through play, not handed over up
    -- front: a New Game resets this to just the avatar (states/prologue.lua's begin), then Rowan
    -- (character_rowan) is sworn in the prologue and the rest join at their own house's counter, the
    -- first time it is walked into after its opener has been run (models/vendor_visit.lua's
    -- joinCompanion). Rowan is the Bastion's companion and reaches his shop long before its door opens,
    -- which is why that counter has nothing to hand over -- the two facts are independent on purpose.
    -- This default is only the non-prologue baseline (Player.reset), kept lean to match. The old
    -- generic Mage/Archer/Priest are retired from the roster -- they live on only as enemy/ally/test
    -- stand-ins (data/quests, tests) with no portrait of their own.
    startingRoster = { "character_rowan" }, -- character ids
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
