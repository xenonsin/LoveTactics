-- Capstone for the TOTEMIST discipline (hunter x priest) -- data/disciplines/totemist.lua names this
-- file in `requiredQuests`.
--
-- Signature on show: WARD TOTEMS -- planted bodies projecting a heal-and-negate zone
-- (utility_carved_stake and ability_raise_totem ship, both planting a `character_totem`). The exemplar
-- is a ward-carver, and the demonstration is the inverse of the Warden's ford: a Warden prices the
-- ground an enemy enters, a Totemist prices the ground her own side stands on, and the difference is
-- what separates two disciplines that both "plant a thing" on paper.
--
-- Disposition is MENTOR, and the objective is `hold` because a ring of stones is ground by
-- definition. She carves, the party stands, and whatever is coming up out of the barrow has until
-- dawn to get through both.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. The ward-carver wants a bespoke
-- blueprint; `character_priest` stands in on the party's side and `character_totem` is already the
-- right body for what she plants.
return {
    name = "The Standing Stones",
    description = "The ring has been re-carved every generation for as long as anyone can name, and " ..
        "this year it was late. Hold inside it until she has finished the last stone.",
    difficulty = "Hard",
    sponsor = "hunters_lodge",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "forest",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Ring",
            composition = function(ctx)
                local list = { "character_gaunt_vigil" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_zombie" end
                return list
            end,
            allies = { "character_priest" },
            -- `region` defaults to "center" for a hold; named because this board IS the ring.
            -- `duration` is in TICKS (the unit the clock counts and the HUD quotes), not turns.
            win = { type = "hold", region = "center", duration = 30 },
        },
        keyCount = 1,
    },
}
