-- Slot 9 of the Bastion's ten: the approach, taken through people loyal to the general rather than
-- through her door.
--
-- Acedia's company -- the ones who walked out of the gate with her and took the terms. They are not
-- prisoners and they do not want rescuing: corruption was the FEE and every one of them agreed to it,
-- thirty years ago, and they will say so. A disciplined knightly company in the Bastion's own forms,
-- holding a line for the first time since they stopped holding one that cost anything.
--
-- And this is where the forty-one marks on the Greywatch gatepost stop being days. Rowan has counted
-- them as her own failure since slot 5. They are the people who did not get out -- and the company
-- standing in front of the player is the people who did. Both halves of the same number, in the same
-- room, thirty years later.
--
-- The last board before the general, so it is the last chance to practise the fight she poses: pairs
-- of spears punishing a formation, which is exactly what her oath will force at slot 10.
return {
    name = "The Forty-First Day",
    description = "The company that walked out with her is still a company, and it is between you " ..
        "and her.",
    difficulty = "Hard",
    sponsor = "bastion",
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
        },
        keyCount = 2,
    },
}
