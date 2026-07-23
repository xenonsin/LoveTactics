--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Haunted Mill",
    description = "Something stalks the old mill after dark. The Cathedral wants it laid to rest.",
    difficulty = "Normal",
    sponsor = "cathedral",
    rewardItems = { "weapon_drowned_censer", "armor_censer_cloth_habit" },
    rewardGold = 120,
    rewardRep = 30,
    rewardPrestige = 1,
    -- Prestige 2, not 1: the Cathedral opens with the city (unlockPrestige 1), but the first-visit
    -- board must show ONLY the Colosseum debut (data/quests/arena_debut.lua), the quest the arrival
    -- coaching points at. The debut pays +1 prestige, so this Mill surfaces the moment it is done --
    -- the tutorial stays a single unambiguous choice, and the Cathedral's line opens right after it.
    requiredPrestige = 2,
    -- Overworld map generated when the quest starts (see models/overworld.lua).
    map = {
        biome = "forest",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Miller's Ghost",
            composition = function(ctx)
                local list = { "character_miller_ghost" }
                if (ctx.prestige or 1) >= 2 then list[#list + 1] = "character_wolf_grunt" end
                return list
            end,
            win = { type = "assassinate", target = "character_miller_ghost" },
        },
        keyCount = 2,
    },
}
