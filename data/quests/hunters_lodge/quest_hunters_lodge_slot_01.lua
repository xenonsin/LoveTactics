-- Hunter's Lodge. The Lodge calls it a cull. The stag's herd calls it something else.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Sacred Stag",
    description = "A white stag walks the deep wood. The Lodge wants its antlers on their wall.",
    difficulty = "Normal",
    sponsor = "hunters_lodge",
    ladder = 0, -- which rung of the Lodge this job opens (models/errand.lua)
    -- The thanks for the job that OPENS this house. Its opener is seated on a descent floor unasked
    -- (models/errand.lua), so this scene is where the house first learns who ran it -- and the greeting
    -- waiting at its counter picks up from these lines.
    outro = "conversation_hunters_lodge_slot_01_outro",
    rewardItems = { "weapon_deadfall_bow", "armor_quarryhide" },
    rewardGold = 130,
    requiredPrestige = 2,
    -- The head of the line waits on the padded card, the same quest that puts the Lodge's door in the
    -- hub (data/buildings/hunters_lodge.lua). Both gates are needed: a building's `unlockQuest` closes
    -- the shop, and Quest.available checks only the vendor's `unlockPrestige`, so without this the
    -- board would offer work at a house the player cannot walk into.
    -- Gated on the DEBUT. This named the padded card (quest_colosseum_slot_02) until the retired
    -- board took that quest with it, and the gate is the same one either way: the first-visit
    -- board shows the Colosseum debut and nothing else, because a tutorial teaches by being the
    -- only thing there. The debut is what survived, so the gate names the debut.
    requiredQuests = { "quest_colosseum_slot_01" },
    map = {
        biome = "forest",
        encounters = { min = 6, max = 9 },
        objective = {
            name = "The White Stag",
            composition = function(ctx)
                local list = { "character_stag_beast" }
                for i = 1, 1 + math.floor((ctx.day or 1) / 2) do list[#list + 1] = "character_boar" end
                if (ctx.day or 1) >= 3 then list[#list + 1] = "character_wolf_alpha" end
                return list
            end,
            win = { type = "assassinate", target = "character_stag_beast", enemy = "the white stag" },
        },
        keyCount = 0,
    },
}
