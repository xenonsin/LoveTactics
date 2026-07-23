-- Slot 2 of the Colosseum's ten (docs/story.md, "The Colosseum: wrath, designed"): the recruit slot's
-- other half -- the card padded with slaughter, and what the house actually sells.
--
-- Saber signs at slot 1 and enjoys herself. This is the first bout after, and the promoter has done
-- the ordinary thing: warmed the crowd up with a bout that is not one. The "opponents" walked out
-- under guard -- debtors, condemned, culls a stable is clearing off its books -- and they are on the
-- sand to die in front of people, which is a product the league sells and has always sold.
--
-- Why it is a fight: the player can refuse the kill, and the house cannot let the card go unfilled, so
-- it sends its own down to finish what the card promised. That is the whole beat -- the venue would
-- rather spend its enforcers than let the crowd go home without a death.
--
-- `killAll` with `protect` layered under it (Combat.evaluate checks `obj.protect` before the win type,
-- so the two compose): kill the house's men, and do not let the culls die while you do it. `protect`
-- holds while ANY unit with that id lives, so losing one costs without ending the run -- deliberate,
-- the same call data/quests/relief_column.lua makes with its wagons.
--
-- What it costs Saber: nothing she will say. She knows exactly what she is looking at, does not
-- explain how, and is the first one down onto the sand between the enforcers and the culls.
--
-- FIRST PASS. Scenes (`intro` / `outro` / the objective's `opening`) and this slot's own unbuyable are
-- not authored yet, so neither is named here -- Conversation.play asserts on an unknown id, and a
-- reward entry pointing at nothing is worse than no entry. Premise, objective and gates are the
-- deliverable. `character_survivor` stands in for the culls until a bespoke blueprint exists.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Padded Card",
    description = "The promoter has warmed the crowd up with a bout that is not one. The people " ..
        "across the sand from you were not brought here to fight.",
    difficulty = "Normal",
    sponsor = "colosseum",
    rewardItems = { "weapon_carrion_axe", "weapon_mired_maul" },
    rewardGold = 90,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 2,
    map = {
        biome = "castle",
        encounters = { min = 4, max = 6 },
        objective = {
            name = "The Warm-Up Bout",
            composition = function(ctx)
                local list = { "character_champion" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_bandit_chief" end
                return list
            end,
            -- The culls. `character_survivor` is defensive and will not walk into the enforcers, which
            -- is what a person shoved onto the sand actually does.
            allies = { "character_survivor", "character_survivor", "character_survivor" },
            win = { type = "killAll", protect = "character_survivor" },
        },
        keyCount = 0,
    },
}
