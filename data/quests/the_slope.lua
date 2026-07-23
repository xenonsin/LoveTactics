-- Slot 8 of the Arcanum's ten: the break, and the quest where humility stops being a temperament and
-- becomes a position someone is willing to lose things over.
--
-- After the demonstration the Arcanum makes Gyeom an offer, and it is not a threat. It is a chair: a
-- seat in the inner circle, the deep stacks, the materials, the standing -- everything the house has,
-- offered by people who genuinely rate her and genuinely believe she has been wasting herself. The
-- price is the same one everyone above her already paid, which is to stop objecting. Nobody frames it
-- that way. Nobody has to.
--
-- She chooses the slope over the summit, deliberately and out loud, and the distinction the whole line
-- rests on lands here: she is not modest because she doubts herself. She holds that she has more to
-- learn, which is a claim about the WORLD being large, not about her being small (docs/story.md,
-- "Gyeom, the same summit reached the other way"). Refusing a summit you could reach is the only
-- version of humility that means anything, and it is the last thing the Arcanum can forgive -- a
-- scholar who could join and will not is a standing argument, and the house closes standing arguments.
--
-- So the sponsor becomes the obstacle. The Magus who made the offer comes to collect her under a
-- warrant that is entirely lawful, because everything here is.
--
-- `assassinate`: the Magus is the mark, and his circle is a wall to get through. He is not a hypocrite
-- and does not think of himself as a villain, and the fight should not let the player pretend he is.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. This slot owes GYEOM'S SECOND RELIC
-- (story.md slot 8: "second relic -- practice that persists -- improvement becomes a stance") and the
-- line's slot-8 unbuyable; neither is written, so no `rewardItems` entry points at them.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Slope",
    description = "They have offered Gyeom the chair, and they mean it kindly. All she has to do is " ..
        "stop objecting. She has said no, and the house does not leave standing arguments standing.",
    difficulty = "Hard",
    sponsor = "arcanum",
    rewardItems = { "weapon_sealed_ward_wand" },
    rewardGold = 320,
    rewardRep = 30,
    rewardPrestige = 2,
    requiredPrestige = 4,
    requiredRep = { vendor = "arcanum", rank = 3 }, -- Magus
    map = {
        biome = "castle",
        encounters = { min = 9, max = 12, always = { "encounter_elite" } },
        objective = {
            name = "The Magus Who Made the Offer",
            composition = function(ctx)
                local list = { "character_mage" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_champion" end
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_zombie" end
                return list
            end,
            win = { type = "assassinate", target = "character_mage" },
        },
        keyCount = 2,
    },
}
