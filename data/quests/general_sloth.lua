-- Slot 10, and the second of the seven generals (docs/story.md). Gated on Lord Commander -- rank 4,
-- the same standing that finally puts the Oathkeeper Shield on the shelf, and the same rank whose item
-- comment has been naming Sloth the whole time. The shield bears her name as a martyr; the standing
-- that lets you buy it is the standing that lets you go and find out what the name was worth.
--
-- `rewardItems` grants the Forsworn Pike, which carries her rule. `gateHint` is this general's
-- fragment of the Gate Below's location: the finale (data/quests/the_gate_below.lua) shows the hints
-- of every general already killed, so the place names itself one sin at a time. Hers is the truest of
-- the seven -- she opened a gate from the inside once already.
--
-- `assassinate`, and here it is load-bearing rather than customary. Her rule bills the party every
-- turn it spends spread out (data/traits/trait_unrelieved.lua), so grinding her guard down is the
-- losing line and it is meant to look tempting. Her own stats are a wall with no threat behind them:
-- she is not trying to kill anyone. She is running the clock, and the clock is what kills you.
--
-- She offers to relieve Rowan before it starts -- stand down, you have done enough, no one is coming
-- and no one ever was. It is the identical offer she has made to every knight she has emptied off the
-- line for fifteen years, and it looks exactly like the one thing Rowan has wanted since Greywatch.
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
    name = "The Unrelieved",
    description = "The Bastion has a founder, and it has been reading her name aloud for fifteen " ..
        "years. Go and find out why she is still able to hear it.",
    difficulty = "Hard",
    sponsor = "bastion",
    intro = "bastion_general_sloth_intro",
    outro = "bastion_general_sloth_outro",
    rewardGold = 500,
    rewardRep = 80,
    rewardPrestige = 3,
    rewardItems = { "weapon_forsworn_pike" },
    requiredPrestige = 5,
    requiredRep = { vendor = "bastion", rank = 4 }, -- Lord Commander
    gateHint = "past the gate that was opened from within",
    map = {
        biome = "castle",
        encounters = { min = 10, max = 14, always = { "encounter_forsworn", "encounter_elite" } },
        objective = {
            name = "Acedia, the Unrelieved",
            composition = function(ctx)
                local list = { "character_general_sloth", "character_forsworn_captain" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do
                    list[#list + 1] = "character_forsworn_knight"
                end
                return list
            end,
            win = { type = "assassinate", target = "character_general_sloth" },
            opening = "bastion_general_sloth_confront",
        },
        keyCount = 2,
    },
}
