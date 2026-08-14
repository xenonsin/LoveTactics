-- The Crucible's mid-line contract, gated on quests-completed rather than prestige: it stays off the board
-- until the player has finished 3 of the Crucible's quests. See `requiredSponsorQuests` in models/quest.lua. Slot
-- 5 of the ten (docs/story.md, "The Crucible") -- the discovery, where the player reaches the manufactory
-- and finds the philosophy laid bare: the hollow discards with their eyes sewn shut, a self treated as
-- inventory and a failed one as a spoiled batch.
--
-- Shippable `killAll` (the resolver knows killAll / assassinate / survive; the `reach` the slot table
-- wants is not yet built): the college's own transmuters stand between the player and the vats, mid-work.
return {
    name = "The Vats",
    description = "There is a wing of the Crucible where people are decanted. Reach it, and read what " ..
        "the philosophy costs the ones it is practised on.",
    difficulty = "Hard",
    sponsor = "alchemist",
    rewardGold = 220,
    requiredQuests = { "quest_alchemist_slot_04" }, -- slot 5: the line runs in order
    requiredPrestige = 4,
    requiredSponsorQuests = { vendor = "alchemist", count = 3 }, -- 3 of this house's quests done
    map = {
        biome = "swamp",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Decanting Wing",
            composition = function(ctx)
                local list = { "character_homunculus" }
                for i = 1, 2 + math.floor((ctx.day or 1) / 2) do list[#list + 1] = "character_champion" end
                return list
            end,
            win = { type = "killAll", enemy = "the wing's keepers" },
        },
        keyCount = 2,
    },
}
