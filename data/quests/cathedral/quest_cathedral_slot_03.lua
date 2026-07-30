-- The Cathedral's second contract, and the first quest gated on quests-completed rather than prestige:
-- it stays off the board until the player has finished 3 of the Cathedral's quests. See
-- `requiredSponsorQuests` in models/quest.lua.
--
-- A `survive` objective: hold the consecrated ground while the rite burns down.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Rite of Ashes",
    description = "The rite takes eight turns and cannot be hurried. Something in the dark knows it.",
    difficulty = "Hard",
    sponsor = "cathedral",
    rewardItems = { "weapon_sealed_censer", "armor_interceding_stole" },
    rewardGold = 220,
    rewardPrestige = 1,
    requiredQuests = { "quest_cathedral_slot_02" }, -- slot 3: the line runs in order
    requiredPrestige = 1,
    requiredSponsorQuests = { vendor = "cathedral", count = 3 }, -- 3 of this house's quests done
    map = {
        biome = "forest",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Consecration",
            composition = function(ctx)
                local list = { "character_miller_ghost" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_wolf_grunt" end
                return list
            end,
            win = { type = "survive", duration = 40 }, -- TICKS to outlast, not turns (the clock's unit)
        },
        keyCount = 1,
    },
}
