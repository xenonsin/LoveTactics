-- The Undercroft's mid-line contract, gated on quests-completed rather than prestige: it stays off the board
-- until the player has finished 3 of the Undercroft's quests. See `requiredSponsorQuests` in models/quest.lua.
-- Slot 5 of the ten (docs/story.md, "The Undercroft") -- the discovery, where the player sets the Bank's
-- proud roll of "accounts settled in full" against what settling meant: the indentured worked to death
-- and the noncompliant quietly closed. A casualty list read as an honor roll, the same trick the Bastion
-- plays with its martyrs.
--
-- Shippable `killAll` (the resolver knows killAll / assassinate / survive; the `reach` the slot table
-- wants is not yet built): the Bank's own enforcers stand between the player and the ledger room.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "Accounts Settled in Full",
    description = "The Bank keeps a proud register of debts cleared. Reach it, and read what clearing a " ..
        "debt cost the ones who owed it.",
    difficulty = "Hard",
    sponsor = "undercroft",
    rewardItems = { "armor_opportunists_harness" },
    rewardGold = 220,
    requiredQuests = { "quest_undercroft_slot_04" }, -- slot 5: the line runs in order
    requiredPrestige = 3,
    requiredSponsorQuests = { vendor = "undercroft", count = 3 }, -- 3 of this house's quests done
    map = {
        biome = "desert",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Ledger Room",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 2 + math.floor((ctx.day or 1) / 2) do list[#list + 1] = "character_bandit" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 2,
    },
}
