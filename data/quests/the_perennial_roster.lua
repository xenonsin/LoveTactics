-- Slot 4 of the Colosseum's ten: the escalation. The reigning stable's roster, met as opponents.
--
-- Other houses recruit, buy and train. This one PRODUCES (docs/story.md, "The Perennial, and what it
-- manufactures") -- it takes children and makes instruments, and it has been winning for longer than
-- anyone finds strange because its product does not feel anything. The player does not learn that
-- here. The player just fights four of them and notices that they fight identically, that none of
-- them flinch, and that they do not celebrate.
--
-- What it costs Saber: she recognises the training from the first exchange and will not say so. She
-- calls the openings before they happen, all four bouts, and when the player asks how, she changes the
-- subject. Slot 5 is where she admits she came out of the same room.
--
-- `killAll`: this is a scheduled team bout, the one place on the line where a purge is honest -- the
-- card is the whole roster and the roster is what the house sent.
--
-- FIRST PASS. Scenes and this slot's own unbuyable are not authored yet, so neither is named (an
-- unknown conversation id asserts in Conversation.play; a dead reward entry is worse than none). The
-- Perennial's own fighters want bespoke blueprints -- identical statlines, no fear, no taunt lines;
-- `character_champion` and `character_bandit_chief` stand in until they exist. The stable's NAME is
-- itself provisional (see story.md's open questions).
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Perennial's Roster",
    description = "The reigning stable has put four of its own on the card against you. Watch how they " ..
        "fight. Watch how they do not celebrate.",
    difficulty = "Normal",
    sponsor = "colosseum",
    rewardItems = { "weapon_hollow_arc", "weapon_long_count" },
    rewardGold = 180,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "colosseum", rank = 2 }, -- Contender
    map = {
        biome = "castle",
        encounters = { min = 6, max = 8, always = { "encounter_elite" } },
        objective = {
            name = "Four of the House's Own",
            composition = function(ctx)
                local list = { "character_champion" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_bandit_chief" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
