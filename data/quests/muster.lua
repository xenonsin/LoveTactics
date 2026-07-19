-- Slot 6 of the Bastion's ten: the grind, and the one entry on the board that stays there.
--
-- `repeatable`, so it is the rung the player can stand on for as long as they like -- but NOT the
-- rung the line depends on. The Colosseum's authored line made its repeatable load-bearing and
-- soft-locked itself doing it (see the note in docs/story.md); the Bastion's eight non-repeatable
-- quests reach rank 4 on their own, and this is here for gold and materials.
--
-- The theme is the repetition itself. Every run is another name off the roll, and the order never
-- once asks why any of them set the shield down. Rowan's lines get shorter each time.
return {
    name = "Muster",
    description = "The roll is long and the Bastion is patient. There is always another name on it.",
    difficulty = "Normal",
    sponsor = "bastion",
    rewardGold = 160,
    rewardRep = 15,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "bastion", rank = 3 }, -- Banneret
    repeatable = true,
    rewardMaterials = { material_steel_ingot = 2 },
    map = {
        biome = "forest",
        encounters = { min = 6, max = 9, always = { "encounter_forsworn" } },
        objective = {
            name = "Another Name",
            composition = function(ctx)
                local list = { "character_forsworn_captain" }
                for i = 1, 1 + math.floor((ctx.prestige or 1) / 3) do
                    list[#list + 1] = "character_forsworn_knight"
                end
                return list
            end,
            win = { type = "assassinate", target = "character_forsworn_captain" },
        },
        keyCount = 1,
    },
}
