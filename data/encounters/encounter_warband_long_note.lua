-- THE LONG NOTE: a company that wants the fight to happen immediately, and in one place.
--
-- A pure TEMPO combo. Provoke drags you into reach, Fury is paid for whoever came, and the Rally Banner
-- hastens the whole line so both happen a turn sooner than they should. The banner is the kill order and
-- it is deliberately not subtle -- this is the early lesson in killing the body that is not hitting you.
--
-- ELITE, not combat: five bodies against Arena.SKIRMISH_CAP of four would trim the combo down to its
-- first four ids on thin ground, and losing the paladin to a clamp turns a set-piece into a brawl. A
-- warband that needs five bodies declares the tier that seats five (Arena.ELITE_CAP).
return {
    name = "The Long Note",
    kind = "elite",
    weight = 2,
    minDay = 6,
    composition = function(ctx)
        local list = {
            "character_warlord",   -- multiplier: the banner, and the whole reason the rest arrive early
            "character_champion",  -- setup: Provoke, which decides where the fight happens
            "character_barbarian", -- payoff: Fury, on whoever the Provoke brought
            "character_paladin",   -- keeps the banner standing
            "character_barbarian",
        }
        for _ = 1, math.floor((ctx.day or 1) / 16) do list[#list + 1] = "character_barbarian" end
        return list
    end,
}
