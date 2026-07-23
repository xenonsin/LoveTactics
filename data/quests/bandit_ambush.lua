-- Quest blueprint. `requiredPrestige` gates when the quest appears on the board, and
-- `sponsor` names the data/vendors/<id>.lua that pays for it -- completing it earns
-- `rewardRep` with that vendor, unlocking more of their stock. `Quest.available(player)`
-- filters on prestige, reputation (`requiredRep`), and what you have already finished.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "Bandit Ambush",
    description = "Raiders have blocked the north road. The Bastion wants it open by week's end.",
    difficulty = "Easy",
    sponsor = "bastion",
    rewardItems = { "weapon_disarming_pike", "armor_reflecting_shield" },
    rewardGold = 50,
    rewardRep = 20,
    rewardPrestige = 1,
    -- Forging stock, spent at the Blacksmith to level up gear (models/material.lua).
    rewardMaterials = { material_iron_scrap = 3 },
    requiredPrestige = 1,
    -- Overworld map generated when the quest starts (see models/overworld.lua).
    map = {
        biome = "forest",
        encounters = { min = 4, max = 6 }, -- map size scales with this; rivers come from the biome
        -- The objective encounter's battle: its enemy roster (composition) and win
        -- condition (win). `win.type` defaults to "killAll" if omitted.
        objective = {
            name = "Bandit Chief",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_bandit" end
                return list
            end,
            win = { type = "assassinate", target = "character_bandit_chief" },
        },
        keyCount = 0,
    },
}
