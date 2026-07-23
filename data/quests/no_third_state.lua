-- Slot 7 of the Colosseum's ten: THE TURN, and the beat the line is built to deliver.
--
-- Ira, briefly reachable -- and the discovery is that there is no third state. She is fighting or she
-- is not there. There is nothing to appeal to, no grievance to settle on her behalf, no name to give
-- back: her handler was not murdered, they were REASSIGNED, by form, and a form has no grave and no
-- throat (docs/story.md, "Ira, and the one thing that ever reached her"). The only sensation the
-- program ever left her is anger, and the only way she gets it is to be hit. So the party hits her, and
-- she wakes up, and that is all the conversation there will ever be.
--
-- What it costs Saber: the hope. She has been carrying a version of this where Ira can be reached --
-- and she watches the player reach her, exactly as far as anyone can, which is not at all.
--
-- WHY IT IS A `survive` AND NOT AN `assassinate`: this is not the finale and she does not die here.
-- The stable SCHEDULES her (it does not fear her and does not appease her), and its stewards pull her
-- off the sand when the bell says so. So the win condition is the bell: outlast her. It also teaches
-- the finale's whole lesson three quests early and on a clock the player survives -- her rule feeds on
-- her own falling health (`trait_wrath_rising`), so a party that stands and grinds her watches the
-- number climb and learns, cheaply, what happens to people who try.
--
-- Story.md flags slot 7 as wanting the antagonist to SPEAK WITHOUT A FIGHT, and notes the only seam
-- for antagonist dialogue is currently attached to a battle (`map.objective.opening`). This file takes
-- the shippable reading: the fight is the staging, and the scene rides its opening. If the no-fight
-- seam is built later, the premise survives the move unchanged.
--
-- FIRST PASS. The opening scene is not authored, so `opening` is not named (Conversation.play asserts
-- on an unknown id).
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "No Third State",
    description = "The house has put you on the sand with its patron. You are not expected to win. " ..
        "Stay standing until the bell, and see whether there is anyone in there to reach.",
    difficulty = "Hard",
    sponsor = "colosseum",
    rewardItems = { "weapon_the_stillness", "armor_blood_fever_mail" },
    rewardGold = 300,
    rewardRep = 30,
    rewardPrestige = 2,
    requiredPrestige = 4,
    requiredRep = { vendor = "colosseum", rank = 3 }, -- Champion
    map = {
        biome = "castle",
        encounters = { min = 8, max = 11, always = { "encounter_elite" } },
        objective = {
            name = "The Patron on the Card",
            composition = function(ctx)
                -- The general herself, three quests before the player may kill her. Deliberate: the
                -- line's thesis is that she cannot be talked to, and the only way to say that is to
                -- put her in front of the player and give them nothing to say it with.
                local list = { "character_general_wrath" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_bandit_chief" end
                return list
            end,
            -- TICKS to outlast (the unit the clock counts and the HUD quotes), not turns.
            win = { type = "survive", duration = 30 },
        },
        keyCount = 2,
    },
}
