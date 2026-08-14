-- The Hunter's Lodge's mid-line contract, gated on quests-completed rather than prestige: it stays off the
-- board until the player has finished 3 of the Lodge's quests. See `requiredSponsorQuests` in models/quest.lua.
-- Slot 5 of the ten (docs/story.md, "The Hunter's Lodge") -- the discovery, where the player sets the
-- Lodge's bounty ledger against a wood gone quiet (a record of extinction) and finds that one "beast" on
-- the wall wore a Grand Hunter's name: the game is the guild's own.
--
-- Shippable `killAll` (the resolver knows killAll / assassinate / survive; the `reach` the slot table
-- wants is not yet built): the beasts the Lodge cultivated stand between the player and the silent
-- heart of the wood. The named turned-hunter horror is deferred (docs/story.md flags a
-- `character_turned_hunter` blueprint as new work); the dire bear stands in for it here.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Silent Wood",
    description = "The Lodge's ledger runs long, and the wood it was written against has gone quiet. " ..
        "Read the last names on your way to the heart.",
    difficulty = "Hard",
    sponsor = "hunters_lodge",
    rewardItems = { "weapon_knell_shaft", "armor_blindfold_cloak" },
    rewardGold = 220,
    requiredQuests = { "quest_hunters_lodge_slot_04" }, -- slot 5: the line runs in order
    requiredPrestige = 2,
    requiredSponsorQuests = { vendor = "hunters_lodge", count = 3 }, -- 3 of this house's quests done
    map = {
        biome = "forest",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Beast That Wore a Name",
            composition = function(ctx)
                local list = { "character_dire_bear" }
                for i = 1, 2 + math.floor((ctx.day or 1) / 2) do list[#list + 1] = "character_wolf_alpha" end
                return list
            end,
            win = { type = "killAll", enemy = "the wood's own" },
        },
        keyCount = 2,
    },
}
