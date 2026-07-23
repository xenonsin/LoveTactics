-- The Arcanum's mid-line contract, gated on reputation rather than prestige: it stays off the board until
-- the player is an Adept (rank 2) with the Arcanum. See `requiredRep` in models/quest.lua. Slot 5 of the
-- ten (docs/story.md, "The Arcanum") -- the discovery, where the player is sent to retrieve the Arcanum's
-- honor roll of "those who gave themselves to the work" and finds what became of them: a casualty list
-- read as a roll of the noble dead, the same trick the Bastion plays with its martyrs.
--
-- Shippable `killAll` (the resolver knows killAll / assassinate / survive; the `reach` the slot table
-- wants is not yet built): the Arcanum's own adepts stand between the player and the register, mid-work.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Donor Roll",
    description = "The Arcanum wants a register recovered from a wing it would rather you not linger in. " ..
        "Read the names on your way out.",
    difficulty = "Hard",
    sponsor = "arcanum",
    rewardItems = { "weapon_second_utterance_wand" },
    rewardGold = 220,
    rewardRep = 45,
    rewardPrestige = 1,
    requiredPrestige = 2,
    requiredRep = { vendor = "arcanum", rank = 2 }, -- Adept or better
    map = {
        biome = "castle",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Reading Wing",
            composition = function(ctx)
                local list = { "character_mage" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_champion" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 2,
    },
}
