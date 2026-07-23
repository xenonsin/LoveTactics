-- Slot 6 of the Hunter's Lodge's ten: complicity, and the hand that empties the wood.
--
-- NOT a grind. No quest in this game is `repeatable`, and the beat here would not survive being one:
-- "the board never closes" is a thing the player has to be shown ONCE, sharply, by a quest that ends
-- -- not something they demonstrate to themselves by farming it, which teaches the opposite lesson
-- (that the board is a faucet, and a convenient one).
--
-- So the premise inverts the line's own sentence. The season closes at first frost and the Lodge
-- clears its book before it does: every open entry on the board, run down in one sweep, with the
-- player as the closing hand. It is a genuine institutional ritual and it is treated as an
-- achievement -- there is a supper afterwards -- and the number of entries is the number the guild
-- posted, which is the number it needed to post (docs/story.md, "The Lodge, and what almost no one
-- sees": the board never closes because the prey renews itself out of the hunters' own ranks).
--
-- The player closes the board, and it will be full again in spring, and the Lodge knows that and is
-- not troubled by it. That is the whole slot: not that the work is endless, but that everyone
-- involved is comfortable with the fact.
--
-- What it costs Kaya: she runs the sweep and takes nothing off any of it, and the wood is quieter
-- behind them at the end of it than it was in the morning -- the sentence data/quests/the_silent_wood.lua
-- spends a whole quest on, delivered here as a day's work with a supper at the end.
--
-- `killAll`: the last entries on the book, and there is no mark worth cutting out. Clearing is the
-- job, which is the point.
--
-- FIRST PASS. Scenes are not authored, so nothing is named, and the slot's own unbuyable is still unwritten.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "Closing the Board",
    description = "First frost closes the season, and the Lodge clears its book before it does. " ..
        "Every open entry, in one sweep. There is a supper afterwards.",
    difficulty = "Hard",
    sponsor = "hunters_lodge",
    rewardItems = { "weapon_witchlight_bow" },
    rewardGold = 240,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "hunters_lodge", rank = 3 }, -- Beastslayer
    map = {
        biome = "forest",
        encounters = { min = 7, max = 10, always = { "encounter_wolf", "encounter_elite" } },
        objective = {
            name = "The Last Entries on the Book",
            composition = function(ctx)
                local list = { "character_dire_bear" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_wolf_grunt" end
                list[#list + 1] = "character_wolf_alpha"
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
