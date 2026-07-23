-- Slot 6 of the Crucible's ten: complicity, and the hand that buries the college's failures.
--
-- NOT a grind. No quest in this game is `repeatable`, and this beat least of all: "the player becomes
-- the thing that disposes of people the college wrote down as stock" is an accusation exactly once,
-- and a chore every time after.
--
-- So it is an inventory writedown with a date on it. The Crucible closes its books at term's end, a
-- season of failures goes out together, and the college has had to hire the job out this year because
-- its own porters have started refusing -- which is the single most damning fact available about the
-- place and is mentioned to the player in passing, as a staffing difficulty.
--
-- The player has known since slot 1 what is in the crates and since slot 5 where they come from. They
-- take the contract because the only ladder to the vats is the college's own errand list, and that
-- trap is the line's, not the player's mistake. The board's wording is the college's own -- a spoiled
-- batch, a bad mix -- and the comforting philosophy licenses exactly that: if a self is a formula, a
-- failed one is inventory (docs/story.md, "The college, and what almost no one sees").
--
-- NAMING: story.md called both this and the Cathedral's slot 6 "Cleansing Work". Two quests cannot
-- share a name on one board, so the Crucible's takes the college's own term. Recorded, not hidden.
--
-- What it costs Ren: she is the only one who says anything over them. She does it quietly, and she
-- does it for all of them, and it takes most of the night.
--
-- `killAll`: the waste ground and everything still moving on it. No mark -- the point of the slot is
-- that there is nobody in charge out here, only a schedule.
--
-- FIRST PASS. Scenes are not authored, so nothing is named, and the slot's own unbuyable is still unwritten.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "Spoiled Batch",
    description = "The Crucible closes its books at term's end and a season of failures goes out " ..
        "together. The college has had to hire it out this year. Its own porters have started refusing.",
    difficulty = "Hard",
    sponsor = "alchemist",
    rewardItems = { "armor_choking_apron" },
    rewardGold = 240,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "alchemist", rank = 3 }, -- Transmuter
    map = {
        biome = "castle",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "The Waste Ground",
            composition = function(ctx)
                local list = { "character_crucible_golem" }
                for i = 1, 4 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_homunculus" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
