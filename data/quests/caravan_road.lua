-- The Bastion's escort contract, and the first quest to use a `protect` objective: the win
-- condition is an ordinary killAll, but the Caravan Master dying loses the battle outright.
-- He spawns from `objective.allies` on the party's side, AI-run (see models/arena.lua).
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Caravan Road",
    description = "A Bastion caravan must reach the pass. The road does not care whether it does.",
    difficulty = "Normal",
    sponsor = "bastion",
    rewardItems = { "weapon_second_rank", "weapon_suspension_mace" },
    rewardGold = 110,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 1,
    map = {
        biome = "forest",
        encounters = { min = 5, max = 7 },
        objective = {
            name = "Ambush at the Pass",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_bandit" end
                return list
            end,
            allies = { "character_caravan_master" }, -- fights beside the party, runs itself
            win = { type = "killAll", protect = "character_caravan_master" },
        },
        keyCount = 0,
    },
}
