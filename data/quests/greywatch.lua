-- Slot 5 of the Bastion's ten: the discovery, and the first piece of evidence that the order is
-- implicated in what it sends you to clean up.
--
-- The ruin itself. The muster roll is still nailed up, and the gate was opened FROM THE INSIDE --
-- a fact the player can read off the hinges and the bar. Rowan's reinterpretation holds, barely:
-- she was betrayed by her own garrison. It is the last reading that lets the martyr survive intact,
-- and it is wrong.
--
-- Beside the gate, forty-one marks scratched into the post. Rowan counts them as days that relief did
-- not come -- her own failure, tallied in stone. They are not days. What they are is slot 9's, and the
-- gap between reading it and learning it is most of the line.
--
-- The reward is the roll (data/items/utility/utility_greywatch_muster_roll.lua): a rule that pays for
-- standing beside people, taken off the wall of a place where nobody did.
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

--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "What Greywatch Kept",
    description = "The fort the doctrine is named after has been empty for fifteen years. Rowan " ..
        "would like to walk it.",
    difficulty = "Normal",
    sponsor = "bastion",
    intro = "bastion_greywatch_intro",
    outro = "bastion_greywatch_outro",
    rewardGold = 220,
    rewardRep = 25,
    rewardPrestige = 2,
    requiredPrestige = 3,
    requiredRep = { vendor = "bastion", rank = 2 }, -- Sworn
    rewardItems = { "utility_greywatch_muster_roll", "weapon_answering_bell", "weapon_rimebell" },
    map = {
        biome = "castle",
        encounters = { min = 8, max = 11, always = { "encounter_forsworn" } },
        objective = {
            name = "The Gate, Opened From Within",
            composition = function(ctx)
                local list = { "character_forsworn_captain" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do
                    list[#list + 1] = "character_forsworn_knight"
                end
                list[#list + 1] = "character_demon_grunt"
                return list
            end,
            -- `reach`: the point is getting THROUGH the ruin to the gate, not clearing it. Acedia's
            -- company holds the ground between, and fighting all of them is the expensive way to
            -- cross -- which is the right shape for the quest where the player learns the gate was
            -- opened from the inside.
            win = { type = "reach", region = "far" },
        },
        keyCount = 2,
    },
}
