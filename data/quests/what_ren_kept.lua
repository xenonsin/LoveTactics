-- Slot 8 of the Crucible's ten: the break, and the hardest beat to write in the line.
--
-- Ren's virtue is kindness read mechanically: she grants others' power instead of coveting it -- she
-- gilds, lifts, mends, and compresses the party upward (docs/story.md, "Ren, the honest alchemist").
-- Her failure mode is the one every giver has: she gives REFLEXIVELY, which is not generosity, it is a
-- way of never being owed anything and never being seen. Six quests of handing things out have left
-- her with nothing of her own and nobody allowed to do anything for her.
--
-- Slot 7 broke the thing she was carrying -- that kindness could give Livia a way out. This is what she
-- does after. The college moves on the shelter she has been running for discards (the thing she was
-- branded a counterfeiter for at slot 2), and the party goes because SHE ASKS. Out loud. Naming a
-- thing she wants, for herself, from people who are under no obligation.
--
-- That is the beat: she learns to receive. It is a small sentence and it is the entire difference
-- between kindness and self-erasure, and the finale does not work without it -- a woman who has never
-- once been given anything has no standing to tell Livia that being given a self is not the same as
-- having one.
--
-- `assassinate`: the college's proctor holds the writ, and the writ is what the raid is. His hands are
-- a wall to get through, not a thing to grind down -- and most of them are ordinary college staff who
-- believe they are recovering stolen property, which they are.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. This slot owes REN'S SECOND RELIC (story.md
-- slot 8: "second relic earned here") and the line's slot-8 unbuyable; neither is written, so there is
-- no `rewardItems` entry pointing at them.
return {
    name = "What Ren Kept",
    description = "The college has a writ for the shelter Ren has been running, and everything in it. " ..
        "For the first time in her life she has asked someone for help.",
    difficulty = "Hard",
    sponsor = "alchemist",
    rewardGold = 320,
    rewardRep = 30,
    rewardPrestige = 2,
    requiredPrestige = 4,
    requiredRep = { vendor = "alchemist", rank = 3 }, -- Transmuter
    map = {
        biome = "castle",
        encounters = { min = 9, max = 12, always = { "encounter_elite" } },
        objective = {
            name = "The Proctor's Writ",
            composition = function(ctx)
                local list = { "character_mage" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_crucible_golem" end
                return list
            end,
            -- The discards in the shelter. Losing them all loses the quest: the raid is only a raid if
            -- there is someone in the building, and the player is the only one who thinks so.
            allies = { "character_homunculus", "character_homunculus" },
            win = {
                type = "assassinate",
                target = "character_mage",
                protect = "character_homunculus",
            },
        },
        keyCount = 2,
    },
}
