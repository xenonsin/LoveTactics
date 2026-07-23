-- Slot 7 of the Cathedral's ten: THE TURN, and the beat the whole line is built to deliver.
--
-- Amana has spent six quests believing two things at once: that the blooding is a crime, and that the
-- Saint who blesses every anointed does not know it is happening. The first is what her plea told the
-- player at slot 2. The second is the thing she has been holding on to, and it is why she has been
-- gathering proof -- proof is only worth carrying to someone who would act on it.
--
-- The Saint knows. The Saint is the demon. The rite Amana wants stopped is not a corruption inside the
-- church, it is the church's own most revered seat doing exactly what it sat down to do (docs/story.md,
-- "Luxuria, the Unbidden"), and the anointed order the world cheers is a sleeper army with one owner.
--
-- WHY IT IS A FIGHT, and what kind: the party goes to the pit with an anointed escort assigned by the
-- chancery, and mid-scene the escort turns -- at a word, from a long way off, without malice and
-- without warning. That is the whole reveal delivered as a mechanic rather than a speech, and it plants
-- the finale's drain-and-turn three quests early. You cannot kill your way out fast enough and you are
-- not meant to: hold until the word stops working. The one soul the word cannot reach is standing next
-- to you, carrying none of that blood, and the player is invited to notice.
--
-- Story.md flags slot 7 across every line as wanting the antagonist to SPEAK WITHOUT A FIGHT, with the
-- only seam for antagonist dialogue currently attached to a battle (`map.objective.opening`). This file
-- takes the shippable reading -- the turn is staged as a fight and the scene rides its opening -- and
-- the premise survives unchanged if the no-fight seam is built later.
--
-- FIRST PASS. Scenes are not authored, so no `opening` is named (Conversation.play asserts on an
-- unknown id). `character_anointed` is the blueprint this wants (story.md's not-built list);
-- `character_knight` and `character_champion` stand in.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "What the Saint Knew",
    description = "The chancery has assigned you an escort of the anointed for the walk to the pit. " ..
        "Somewhere behind you, someone says a word.",
    difficulty = "Hard",
    sponsor = "cathedral",
    rewardItems = { "armor_hem_of_the_stayed_hand" },
    rewardGold = 300,
    rewardRep = 30,
    rewardPrestige = 2,
    requiredPrestige = 4,
    requiredRep = { vendor = "cathedral", rank = 3 }, -- Confessor
    map = {
        biome = "castle",
        encounters = { min = 8, max = 11, always = { "encounter_elite" } },
        objective = {
            name = "The Escort",
            composition = function(ctx)
                local list = { "character_champion" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_knight" end
                return list
            end,
            -- TICKS to outlast (the unit the clock counts and the HUD quotes). Outlasting, not
            -- clearing: they are not enemies, they are people being used, and the fight ends when the
            -- word does.
            win = { type = "survive", duration = 32 },
        },
        keyCount = 2,
    },
}
