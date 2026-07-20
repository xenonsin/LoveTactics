-- Slot 6 of the Bastion's ten: the grind, and the one entry on the board that stays there.
--
-- `repeatable`, so it is the rung the player can stand on for as long as they like -- but NOT the
-- rung the line depends on. The Colosseum's authored line made its repeatable load-bearing and
-- soft-locked itself doing it (see the note in docs/story.md); the Bastion's eight non-repeatable
-- quests reach rank 4 on their own, and this is here for gold and materials.
--
-- The theme is the repetition itself. Every run is another name off the roll, and the order never
-- once asks why any of them set the shield down. Rowan's lines get shorter each time.
-- WIP -- THIS SLOT HAS NOT BEEN THROUGH THE PREMISE PASS.
--
-- Slots 1 and 2 were rebuilt premise-first: what is actually happening, how it bears on Rowan AND on
-- sloth, what the objective is, and which unique item carries the narrative. Doing that to slot 1
-- turned up a duplicated quest with no logistics under its fiction; doing it to slot 2 turned up a
-- premise that could not survive the question "why is this a fight?" and had to be replaced
-- outright. Assume the same of this file until it has had the same pass.
--
-- Known stale here: scenes and items below were authored against the OLD slot-2 backstory (three
-- officers who turned a relief column around -- they do not exist any more; slot 2 is now the
-- nineteen who refused Acedia's terms and were struck off the rolls), and the timeline moved from
-- thirty years to fifteen. Text may still lean on beats that have been rewritten upstream.

return {
    name = "Muster",
    description = "The roll is long and the Bastion is patient. There is always another name on it.",
    difficulty = "Normal",
    sponsor = "bastion",
    -- Repeatable, so both scenes are written to read the same on the fifth run as the first.
    intro = "bastion_muster_intro",
    outro = "bastion_muster_outro",
    -- Granted on EVERY completion: repeatable quests skip the double-payout guard in
    -- models/quest.lua, which is why slot 6's item is a consumable that stacks.
    rewardItems = { "consumable_bannerets_steel" },
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
