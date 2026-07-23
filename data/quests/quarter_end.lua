-- Slot 6 of the Undercroft's ten: complicity, and the hand the Bank hires.
--
-- NOT a grind. No quest in this game is `repeatable`, and greed's version of the beat would be
-- actively ruined by being one: a farmable collection route pays the player gold for running the
-- Bank's errands, over and over, at their own choosing -- which is not an indictment of the machine,
-- it IS the machine, offered as a feature. Said once, with a date on it, it is the accusation it was
-- meant to be.
--
-- So it is quarter-end. The Bank closes its books, every outstanding route runs on the same night
-- across the city, and the firm beneath it hires out the overflow -- which is the player. Nothing
-- here is a robbery and nothing is a murder. It is lawful recovery of secured property, the paperwork
-- is impeccable, the contractors are paid on completion at a posted rate, and by morning the ledger
-- balances and the quarter is closed and a number of addresses are empty.
--
-- That is what makes greed the hardest of the seven to name (docs/story.md, "The Bank, and what
-- everyone already accepts): you cannot point at a crypt, you can only refuse to keep calling the
-- water dry. This quest is the water, and the player drinks it for standing.
--
-- What it costs Clem: she runs it. She used to be the best there ever was at this and she is still
-- very good, and the player watches her be good at it for a whole night. She does not make a speech
-- afterwards. She goes and sits somewhere else.
--
-- `killAll`: the last address on the night's list, and the resistance in it. No mark, because the
-- point of the slot is that nobody in the chain is in charge and everybody is following a schedule.
--
-- FIRST PASS. Scenes are not authored, so nothing is named, and the slot's own unbuyable is still unwritten.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "Quarter-End",
    description = "The Bank closes its books tonight and every outstanding route in the city runs at " ..
        "once. The firm is hiring out the overflow. Posted rate, paid on completion.",
    difficulty = "Hard",
    sponsor = "undercroft",
    rewardItems = { "weapon_thin_place" },
    rewardGold = 240,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "undercroft", rank = 3 }, -- Shadow
    map = {
        biome = "castle",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "The Last Address on the List",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 4 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_bandit" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
