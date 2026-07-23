-- Capstone for the THEURGE discipline (mage x priest) -- data/disciplines/theurge.lua names this file
-- in `requiredQuests`.
--
-- Signature on show: CHANNELLED MIRACLE -- a wind-up whose payoff scales with how long it was held
-- (ability_invocation and weapon_litany_staff ship). The exemplar is a channelling divine, and the
-- demonstration is the trade every channel makes: what she is building is worth more than anything
-- else on the board and it is worth nothing at all if she is interrupted, so the fight is a clock
-- with a person standing in the middle of it.
--
-- Disposition is MENTOR, and the objective is `hold` with `protect` under it (Combat.evaluate checks
-- `obj.protect` before the win type, so the two compose): keep the ground and keep her breathing. The
-- twin liturgy needs two voices and she has one, which is why she asked.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. The divine wants a bespoke blueprint
-- carrying the Invocation; `character_priest` stands in and channels nothing.
return {
    name = "The Twin Liturgy",
    description = "It takes two voices and she has one. Hers will be occupied for some time, and " ..
        "everything within a mile knows exactly what she is doing.",
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
            name = "The Channel",
            composition = function(ctx)
                local list = { "character_demon_champion" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_demon_imp" end
                return list
            end,
            allies = { "character_priest" },
            -- `region` defaults to "center" for a hold; named because the channel is the middle of the
            -- board. `duration` is in TICKS (the unit the clock counts and the HUD quotes), not turns.
            win = { type = "hold", region = "center", duration = 32, protect = "character_priest" },
        },
        keyCount = 1,
    },
}
