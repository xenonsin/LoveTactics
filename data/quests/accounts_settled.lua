-- The Undercroft's mid-line contract, gated on reputation rather than prestige: it stays off the board
-- until the player is a Prowler (rank 2) with the Undercroft. See `requiredRep` in models/quest.lua.
-- Slot 5 of the ten (docs/story.md, "The Undercroft") -- the discovery, where the player sets the Bank's
-- proud roll of "accounts settled in full" against what settling meant: the indentured worked to death
-- and the noncompliant quietly closed. A casualty list read as an honor roll, the same trick the Bastion
-- plays with its martyrs.
--
-- Shippable `killAll` (the resolver knows killAll / assassinate / survive; the `reach` the slot table
-- wants is not yet built): the Bank's own enforcers stand between the player and the ledger room.
return {
    name = "Accounts Settled in Full",
    description = "The Bank keeps a proud register of debts cleared. Reach it, and read what clearing a " ..
        "debt cost the ones who owed it.",
    difficulty = "Hard",
    sponsor = "undercroft",
    rewardGold = 220,
    rewardRep = 45,
    rewardPrestige = 1,
    requiredPrestige = 2,
    requiredRep = { vendor = "undercroft", rank = 2 }, -- Prowler or better
    map = {
        biome = "castle",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Ledger Room",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_bandit" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 2,
    },
}
