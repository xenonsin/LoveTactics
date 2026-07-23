-- Slot 7 of the Arcanum's ten: THE TURN, and it is the strangest of the six because the reveal is that
-- the villain is not a fraud.
--
-- Every other line's slot 7 takes something away from the player. This one takes it away from the
-- audience: Sublimitas glances a working once and reproduces it flawlessly, in front of everyone, and
-- she is genuinely the greatest mage of the age -- celebrated, real, earned in her own eyes (docs/
-- story.md, "Sublimitas, the Unequalled"). There is no exposure available. Nothing she does is a trick
-- and nothing about her is hollow. That is precisely why she never stops and can hear no objection:
-- perfection is a ceiling, and a mind that has decided there is nothing left to learn cannot be told
-- anything.
--
-- And she measures Gyeom at a glance -- a quiet mage who has shown her nothing -- and dismisses her,
-- accurately by her own instrument and completely wrongly. GYEOM MUST NOT CORRECT HER. That is the
-- whole slot. The player watches a companion decline to defend herself and has to sit with not knowing
-- whether the dismissal was fair, for three more quests, until the finale answers it.
--
-- WHY IT IS A FIGHT, and what kind: she demonstrates. She takes whatever the party throws and hands it
-- back better -- her `onCast` rule, shipped as the foreshadow (story.md, "Authoring the remaining six
-- lines") -- and she leaves when she is finished, because she came to settle a question about herself
-- and not about the player. `survive`: you cannot beat her, you can only be measured. The counterplay
-- the finale wants -- DO NOT SHOW HER YOUR HAND -- is teachable here at a survivable price, and a
-- player who works that out on this board will walk into slot 10 already holding the answer.
--
-- Story.md flags slot 7 across every line as wanting the antagonist to SPEAK WITHOUT A FIGHT, the only
-- antagonist-dialogue seam being attached to a battle (`map.objective.opening`). This file takes the
-- shippable reading; the premise survives unchanged if the no-fight seam is built later.
--
-- FIRST PASS. Scenes are not authored, so no `opening` is named (Conversation.play asserts on an
-- unknown id), and the slot's own unbuyable is still unwritten.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "At a Glance",
    description = "The Unequalled has come to watch a working, and to reproduce it. She will look at " ..
        "your party exactly once, and she will be sure that was enough.",
    difficulty = "Hard",
    sponsor = "arcanum",
    rewardItems = { "weapon_overchannelled_staff" },
    rewardGold = 300,
    rewardRep = 30,
    rewardPrestige = 2,
    requiredPrestige = 4,
    requiredRep = { vendor = "arcanum", rank = 3 }, -- Magus
    map = {
        biome = "castle",
        encounters = { min = 8, max = 11, always = { "encounter_elite" } },
        objective = {
            name = "The Demonstration",
            composition = function(ctx)
                -- The general herself, three quests before the player may kill her. Deliberate, and
                -- the same call data/quests/no_third_state.lua makes with Ira: the line's thesis is
                -- that she cannot be argued with, and the only way to say that is to put her in front
                -- of the player and give them nothing to say it with.
                local list = { "character_general_pride" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_zombie" end
                return list
            end,
            -- TICKS to outlast (the unit the clock counts and the HUD quotes), not turns.
            win = { type = "survive", duration = 32 },
        },
        keyCount = 2,
    },
}
