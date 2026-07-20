-- Slot 9 of the Bastion's ten: the approach, taken through people loyal to the general rather than
-- through her door.
--
-- Acedia's company -- the ones who walked out of the gate with her and took the terms. They are not
-- prisoners and they do not want rescuing: corruption was the FEE and every one of them agreed to it,
-- fifteen years ago, and they will say so. A disciplined knightly company in the Bastion's own forms,
-- holding a line for the first time since they stopped holding one that cost anything.
--
-- And this is where the forty-one marks on the Greywatch gatepost stop being days. Rowan has counted
-- them as her own failure since slot 5. They are the people who did not get out -- and the company
-- standing in front of the player is the people who did. Both halves of the same number, in the same
-- room, fifteen years later.
--
-- The last board before the general, so it is the last chance to practise the fight she poses: pairs
-- of spears punishing a formation, which is exactly what her oath will force at slot 10.
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
    name = "The Forty-First Day",
    description = "The company that walked out with her is still a company, and it is between you " ..
        "and her.",
    difficulty = "Hard",
    sponsor = "bastion",
    intro = "bastion_forty_first_day_intro",
    outro = "bastion_forty_first_day_outro",
    rewardItems = { "utility_forty_one_marks" },
    rewardGold = 400,
    rewardRep = 35,
    rewardPrestige = 2,
    requiredPrestige = 5,
    requiredRep = { vendor = "bastion", rank = 3 }, -- Banneret
    map = {
        biome = "castle",
        encounters = { min = 10, max = 13, always = { "encounter_forsworn", "encounter_forsworn" } },
        objective = {
            name = "The Company That Left",
            composition = function(ctx)
                local list = { "character_forsworn_captain", "character_forsworn_captain" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do
                    list[#list + 1] = "character_forsworn_knight"
                end
                return list
            end,
            win = { type = "killAll" },
            opening = "bastion_forty_first_day_confront",
        },
        keyCount = 2,
    },
}
