-- THE WANDERING CHAPTER: the onAnyDeath company, where killing things is how it grows.
--
-- Every other fight on the floor is answered by killing the bodies in front of you. This one inverts
-- that: Contagion spreads on contact, Raise Dead reaps whatever fell -- yours or its own -- and the
-- necromancer is fed by the exchange rather than spent by it. The counter is to kill the RAISER, not
-- the wave, which is the whole point of putting it on the same floor as three warbands that punish
-- exactly the opposite instinct.
--
-- It is also the bridge out of the human half of the bestiary: a company of people that fields the dead.
return {
    name = "The Wandering Chapter",
    kind = "elite",
    weight = 2,
    minDay = 8,
    composition = function(ctx)
        local list = {
            "character_necromancer",  -- payoff: every death on the board is its resource
            "character_plague_knight", -- setup: Contagion, which makes the deaths happen
            "character_zombie",
            "character_zombie",
            "character_zombie",
        }
        for _ = 1, math.floor((ctx.day or 1) / 13) do list[#list + 1] = "character_zombie" end
        return list
    end,
}
