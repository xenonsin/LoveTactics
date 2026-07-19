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
return {
    name = "What Greywatch Kept",
    description = "The fort the doctrine is named after has been empty for thirty years. Rowan " ..
        "would like to walk it.",
    difficulty = "Normal",
    sponsor = "bastion",
    rewardGold = 220,
    rewardRep = 25,
    rewardPrestige = 2,
    requiredPrestige = 3,
    requiredRep = { vendor = "bastion", rank = 2 }, -- Sworn
    rewardItems = { "utility_greywatch_muster_roll" },
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
            win = { type = "killAll" },
        },
        keyCount = 2,
    },
}
