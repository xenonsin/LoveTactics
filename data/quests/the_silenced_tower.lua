-- Capstone for the SPELLBREAKER discipline (knight x mage) -- data/disciplines/spellbreaker.lua names
-- this file in `requiredQuests`.
--
-- Signature on show: COUNTERSPELL -- interrupt the channel, burn the pool, lock the caster out
-- (ability_null_field and ability_mana_sunder ship). The exemplar is an anti-mage sword-oath, and the
-- demonstration is the most uncomfortable one in the slate, because it is aimed squarely at the
-- player: bring your mage and watch her not get a turn. Everything the party has learned about opening
-- with the big spell is the wrong opening here.
--
-- Disposition is BOSS. Her oath is sincere and her order is not wrong that the Arcanum should be
-- afraid of somebody -- she has simply decided that everyone who can cast is the same problem, and
-- the party contains counter-examples she will not look at.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. The sword-oath wants a bespoke blueprint
-- whose grid is the two silencing abilities; `character_champion` stands in and silences nobody.
return {
    name = "The Silenced Tower",
    description = "Nothing has been cast inside that tower in six weeks. The order that arranged " ..
        "that is still in the stairwell, and they took an oath about people like you.",
    difficulty = "Hard",
    sponsor = "arcanum",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "castle",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "The Sword-Oath",
            composition = function(ctx)
                local list = { "character_champion" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_knight" end
                return list
            end,
            win = { type = "assassinate", target = "character_champion" },
        },
        keyCount = 1,
    },
}
