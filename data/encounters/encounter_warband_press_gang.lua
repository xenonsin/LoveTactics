-- THE PRESS-GANG: the teaching fight, and the only warband written for floors one and two.
--
-- One clear combo and nothing else going on. Bolas roots a body, the gang collapses on the rooted one,
-- and the ambusher's traps hold the ground it would have retreated across. What it punishes is letting a
-- single unit get isolated -- which is the first thing a new company does wrong and the last thing any
-- other warband here will forgive.
--
-- `minDay = 1` and the heaviest weight in the set: this is what the shallow floors should be meeting
-- instead of a lone stag.
return {
    name = "The Press-Gang",
    kind = "combat",
    weight = 6,
    minDay = 1,
    composition = function(ctx)
        local list = {
            "character_bandit_chief",     -- the lead, and the body worth killing first
            "character_poacher",          -- setup: Bolas roots whoever strayed
            "character_trapper_ambusher", -- multiplier: the ground behind the rooted body
            "character_bandit",           -- payoff: the gang, arriving on somebody who cannot leave
        }
        for _ = 1, math.floor((ctx.day or 1) / 9) do list[#list + 1] = "character_bandit" end
        return list
    end,
}
