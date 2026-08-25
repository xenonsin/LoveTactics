--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "Siege of Warlord's Keep",
    description = "The Warlord once fought under the Colosseum's banner. They want him brought back, or brought down.",
    difficulty = "Hard",
    sponsor = "colosseum",
    intro = "conversation_colosseum_slot_03_intro",
    outro = "conversation_colosseum_slot_03_outro",
    rewardItems = { "weapon_bellfounders_hammer", "armor_rally_coat", "utility_last_order" },
    rewardGold = 300,
    -- Gated on the DEBUT. This named the padded card (quest_colosseum_slot_02) until the retired
    -- board took that quest with it, and the gate is the same one either way: the first-visit
    -- board shows the Colosseum debut and nothing else, because a tutorial teaches by being the
    -- only thing there. The debut is what survived, so the gate names the debut.
    requiredQuests = { "quest_colosseum_slot_01" },
    requiredPrestige = 1,
    -- Overworld map generated when the quest starts (see models/overworld.lua).
    map = {
        biomes = { "castle", "volcanic" },
        encounters = { min = 10, max = 14, always = { "encounter_elite", "encounter_elite" } },
        objective = {
            name = "The Warlord",
            composition = function(ctx)
                local list = { "character_warlord" }
                for i = 1, 2 + math.floor((ctx.day or 1) / 3) do list[#list + 1] = "character_champion" end
                return list
            end,
            win = { type = "assassinate", target = "character_warlord", enemy = "the Warlord" },
        },
        keyCount = 2,
    },
}
