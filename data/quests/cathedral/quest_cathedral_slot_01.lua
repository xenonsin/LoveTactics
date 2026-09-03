--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Haunted Mill",
    description = "Something stalks the old mill after dark. The Cathedral wants it laid to rest.",
    difficulty = "Normal",
    sponsor = "cathedral",
    -- The thanks for the job that OPENS this house. Its opener is seated on a descent floor unasked
    -- (models/errand.lua), so this scene is where the house first learns who ran it -- and the greeting
    -- waiting at its counter picks up from these lines.
    outro = "conversation_cathedral_slot_01_outro",
    rewardItems = { "weapon_drowned_censer", "armor_censer_cloth_habit" },
    rewardGold = 120,
    -- THE COMPANION JOINS HERE. This is the ask they make when you meet them on a floor
    -- (models/errand.lua), and clearing it is what brings them into the company -- the same
    -- route Saber has always arrived by. Quest.complete calls Player.recruit before the outro
    -- fires, so the "[X has joined your Party]" banner and their first words land in one beat.
    rewardCharacter = "character_amana",
    -- Gated on the PADDED CARD, not the debut. Two reasons and they are the same reason: the
    -- first-visit board must show only the Colosseum debut (the quest the arrival coaching points at),
    -- and this house is not open to the player until they have been carried into it dead
    -- (data/quests/colosseum/quest_colosseum_slot_02.lua, and the building's own comment). The Mill
    -- surfaces the morning after the revival, with the acolyte who performed it already on the roster.
    -- Gated on the DEBUT. This named the padded card (quest_colosseum_slot_02) until the retired
    -- board took that quest with it, and the gate is the same one either way: the first-visit
    -- board shows the Colosseum debut and nothing else, because a tutorial teaches by being the
    -- only thing there. The debut is what survived, so the gate names the debut.
    requiredQuests = { "quest_colosseum_slot_01" },
    requiredPrestige = 1,
    -- Overworld map generated when the quest starts (see models/overworld.lua).
    map = {
        biome = "swamp",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Miller's Ghost",
            composition = function(ctx)
                local list = { "character_miller_ghost" }
                if (ctx.day or 1) >= 2 then list[#list + 1] = "character_wolf_grunt" end
                return list
            end,
            win = { type = "assassinate", target = "character_miller_ghost" },
        },
        keyCount = 2,
    },
}
