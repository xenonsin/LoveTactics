-- Capstone for the PALADIN discipline (knight x priest) -- data/disciplines/paladin.lua names this
-- file in `requiredQuests`.
--
-- Signature on show: WARD AURA -- a persistent damage-reduction bubble on everyone adjacent
-- (utility_aegis_of_the_oath and ability_consecrate ship; the Aegis is an `incense` charm, a walking
-- zone, which is the engine's honest home for a bubble that moves with its bearer). The exemplar is a
-- sworn holy knight keeping a shrine, and the demonstration is positional: her people are unkillable
-- while they stand with her and ordinary the moment they step off, so the fight is really about the
-- three tiles around one body.
--
-- Disposition is MENTOR. She is defending a shrine full of people who came to it, and the party's job
-- is the same as hers -- which is why this is a `killAll` with `protect` layered under it
-- (Combat.evaluate checks `obj.protect` before the win type, so the two compose) rather than a duel.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. The sworn knight wants a bespoke
-- blueprint carrying the Aegis; `character_knight` stands in and projects nothing.
return {
    name = "The Oath at the Altar",
    description = "She swore to hold this shrine and the people in it, in that order, and she has " ..
        "been holding it for two days. The next wave is at the door.",
    difficulty = "Hard",
    sponsor = "cathedral",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "castle",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Shrine",
            composition = function(ctx)
                local list = { "character_demon_champion" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_demon_grunt" end
                return list
            end,
            allies = { "character_knight", "character_survivor", "character_survivor" },
            win = { type = "killAll", protect = "character_survivor" },
        },
        keyCount = 1,
    },
}
