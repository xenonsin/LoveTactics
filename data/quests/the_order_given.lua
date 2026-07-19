-- Slot 7 of the Bastion's ten: THE TURN, and the beat the whole line is built to deliver.
--
-- One document, in the order's own archive: the decision that wrote Greywatch off, the standing
-- practice that turned Rowan's column back as part of the same calculation, and -- the fact that ends
-- everything -- the TIMESTAMP on the gate. Acedia opened it before any relief was ever due.
--
-- So Rowan is innocent. There was no window to miss, no battle to arrive at, and no army in the world
-- could have been early enough to matter. And she will not take it, because absolution costs her the
-- martyr: if she could not have come in time, there was nothing to come FOR. She would rather be
-- guilty. That refusal is the best scene in the line and it is the reason slot 7 exists at all -- a
-- four-quest vendor line has nowhere to put it.
--
-- The rank-4 shield has been naming this general in its file comment since the player could afford
-- it, so most players will have connected Acedia to the general several quests ago. Rowan has not.
-- Do not close that gap early; watching her not see it is worth more than a shared reveal.
return {
    name = "The Order That Was Given",
    description = "The Bastion's archive keeps everything, including the things it stopped reading. " ..
        "Rowan wants the file on Greywatch.",
    difficulty = "Hard",
    sponsor = "bastion",
    rewardGold = 300,
    rewardRep = 30,
    rewardPrestige = 2,
    requiredPrestige = 4,
    requiredRep = { vendor = "bastion", rank = 3 }, -- Banneret
    map = {
        biome = "castle",
        encounters = { min = 9, max = 12, always = { "encounter_forsworn", "encounter_elite" } },
        objective = {
            name = "The Archivist's Guard",
            composition = function(ctx)
                local list = { "character_forsworn_captain" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do
                    list[#list + 1] = "character_forsworn_knight"
                end
                return list
            end,
            win = { type = "assassinate", target = "character_forsworn_captain" },
        },
        keyCount = 2,
    },
}
