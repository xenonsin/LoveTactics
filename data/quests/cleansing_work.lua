-- Slot 6 of the Cathedral's ten: complicity, and the worst thing in the line.
--
-- NOT a grind. No quest in this game is `repeatable`, and this slot in particular must not be: a beat
-- whose whole content is "the player becomes the hand that buries the evidence" is destroyed by being
-- optional and farmable. Run once, deliberately, in the ladder's middle, it is an accusation. Run
-- eleven times for gold it is a chore, and the accusation becomes something the player tuned out.
--
-- So it is one commissioned job with a date on it. The Feast of the Ascended is in three days -- the
-- one where the register of the church's glorious dead is read aloud (data/quests/roll_of_the_given.lua)
-- -- and the chancery wants every outstanding sighting in the diocese closed before the pilgrims
-- arrive. Not hidden. TIDIED. It is a scheduling problem to the people who commissioned it, and the
-- work order says so.
--
-- The player has known since slot 4 what the "corruption" is: failed bloodings, the church's own
-- children (docs/story.md, "The blooding"). They take the commission anyway, because the only ladder
-- up to the Saint is the Saint's own errand list, and that trap is the line's, not the player's
-- mistake. Do not editorialise it in the text -- the description should read like a work order,
-- because that is what makes it land.
--
-- What it costs Amana: she comes, and she says the names, and the feast happens on schedule.
--
-- `killAll`: there is no mark and no room to reach. Clearing the board IS the job, and the job is
-- what the church wanted -- the same shape slot 4 had, now with the player knowing.
--
-- FIRST PASS. Scenes are not authored, so no `intro` / `outro` / `opening` is named (Conversation.play
-- asserts on an unknown id), and the slot's own unbuyable is still unwritten.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "Cleansing Work",
    description = "The Feast of the Ascended is in three days and the diocese has four open " ..
        "sightings on it. The chancery would like the list closed before the pilgrims arrive.",
    difficulty = "Hard",
    sponsor = "cathedral",
    rewardItems = { "weapon_censer_of_the_grasping_hollow" },
    rewardGold = 240,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "cathedral", rank = 3 }, -- Confessor
    map = {
        biome = "forest",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "The Last Entry on the List",
            composition = function(ctx)
                local list = { "character_demon_grunt" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_demon_imp" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
