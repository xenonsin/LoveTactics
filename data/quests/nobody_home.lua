-- Slot 7 of the Crucible's ten: THE TURN, and the beat the whole line is built to deliver.
--
-- Ren has been carrying one hope through six quests, and it is the exact shape of her virtue: that
-- kindness can GIVE Livia a way out. She grants others' power instead of coveting it; the thing at the
-- centre of the vats wants what it cannot make; therefore -- and it is a good argument, and it is the
-- reason she came -- there is something to hand over.
--
-- There is not. Livia is not a monster the college accidentally produced. She IS the thesis (docs/
-- story.md, "Livia, the Unborn"): the pact gave her the power to copy any human perfectly and never
-- once to BE one, so she can be anyone and is no one, and there is no interior to fill. Her death frees
-- nothing and her survival frees nothing, because the engine is not her -- it is the philosophy that
-- says a self is inventory, and that teaching is popular, consoling, and taught in the open.
--
-- WHY IT IS A FIGHT, and what kind: she meets the party wearing the party. The board fills with
-- counterfeits of people standing next to the player, each one inert until it SEES someone to be, and
-- she talks the whole time -- pleasantly, without malice, from behind faces the player recognises. She
-- cannot be reached and cannot be killed here. Outlast the conversation. It plants the finale's
-- Counterfeit Host three quests early and teaches its counterplay -- do not let one unit tower, do not
-- show her a shape worth wearing -- on a clock the player survives.
--
-- Story.md flags slot 7 across every line as wanting the antagonist to SPEAK WITHOUT A FIGHT, the only
-- antagonist-dialogue seam being attached to a battle (`map.objective.opening`). This file takes the
-- shippable reading; the premise survives unchanged if the no-fight seam is built later.
--
-- FIRST PASS. Scenes are not authored, so no `opening` is named (Conversation.play asserts on an
-- unknown id). The counterfeits want `Summon.copyOf` against the live party rather than a fixed
-- composition -- the finale's own trick, and the right build for this slot when it is wired.
-- `character_homunculus` stands in.
return {
    name = "Nobody Home",
    description = "She has come to meet you, and she has come wearing your people. She would like to " ..
        "talk. There is no one in there to talk to.",
    difficulty = "Hard",
    sponsor = "alchemist",
    rewardGold = 300,
    rewardRep = 30,
    rewardPrestige = 2,
    requiredPrestige = 4,
    requiredRep = { vendor = "alchemist", rank = 3 }, -- Transmuter
    map = {
        biome = "castle",
        encounters = { min = 8, max = 11, always = { "encounter_elite" } },
        objective = {
            name = "The Counterfeit Host",
            composition = function(ctx)
                local list = { "character_crucible_golem" }
                for i = 1, 4 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_homunculus" end
                return list
            end,
            -- TICKS to outlast (the unit the clock counts and the HUD quotes), not turns.
            win = { type = "survive", duration = 32 },
        },
        keyCount = 2,
    },
}
