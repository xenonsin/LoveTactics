-- THE BROKEN COLUMN: deserters who kept their drill.
--
-- The one warband whose combo is POSITION rather than a status. Nothing here is individually
-- frightening; the shape is. trait_formation_fighter measures adjacency continuously, so a rank that
-- stays closed is armoured and a rank pulled apart is four ordinary soldiers -- which makes this the
-- fight that teaches a player to break a formation instead of grinding one.
--
-- The warden is the multiplier and the honest kill order: its Warding Line denies the flank the whole
-- combo is answered by. See encounter_warband_vat_work.lua for the role grammar.
return {
    name = "The Broken Column",
    kind = "combat",
    weight = 4,
    minDay = 2,
    composition = function(ctx)
        local list = {
            "character_forsworn_captain", -- setup: the oath that armours the rank
            "character_forsworn_knight",  -- payoff: enormous inside the formation, ordinary outside it
            "character_warden",           -- multiplier: the flank is where the answer was
            "character_forsworn_knight",
        }
        for _ = 1, math.floor((ctx.day or 1) / 10) do list[#list + 1] = "character_forsworn_knight" end
        return list
    end,
}
