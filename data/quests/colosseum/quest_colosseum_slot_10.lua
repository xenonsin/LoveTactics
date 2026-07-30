-- The end of the Colosseum's line, and the first of the seven generals (docs/story.md). Gated on
-- Legend -- rank 4, the same standing that finally puts the Crimson Greataxe on the shelf, and the
-- same rank whose item comment has been naming Wrath the whole time.
--
-- `rewardItems` grants Ira's mail, which carries her rule. `gateHint` is this general's fragment of
-- the Gate Below's location: the finale (data/quests/quest_the_gate_below.lua) shows the hints of every
-- general already killed, so the place names itself one sin at a time.
--
-- The objective is `assassinate` rather than `killAll`: her guard is a wall to get through, not a
-- thing to grind down. Every turn spent on them is a turn she spends being hit and growing.
return {
    name = "The Unappeased",
    description = "The Colosseum has a patron, and she has never once been satisfied. Go and satisfy her.",
    difficulty = "Hard",
    sponsor = "colosseum",
    rewardGold = 500,
    rewardPrestige = 3,
    rewardItems = { "armor_mail_of_the_unappeased" },
    requiredQuests = { "quest_colosseum_slot_09" }, -- slot 10: the line runs in order
    requiredPrestige = 1,
    requiredSponsorQuests = { vendor = "colosseum", count = 10 }, -- 10 of this house's quests done
    gateHint = "beneath the sand, where the roaring was loudest",
    map = {
        biome = "castle",
        encounters = { min = 10, max = 14, always = { "encounter_elite", "encounter_elite" } },
        objective = {
            name = "Ira, the Unappeased",
            -- The only seam she can speak from, and the last of the seven generals to get one.
            opening = "conversation_colosseum_slot_10_confront",
            composition = function(ctx)
                local list = { "character_general_wrath" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_champion" end
                return list
            end,
            win = { type = "assassinate", target = "character_general_wrath" },
        },
        keyCount = 2,
    },
}
