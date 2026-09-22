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
    -- OPEN FROM THE FIRST FLOOR. The human band is the one thing that appears at every depth --
    -- everything else is locked to its circle -- so it is what keeps a shallow floor from being
    -- empty, and it cannot do that job from behind a gate. Every body in this one is human, so
    -- nothing here is a circle's content arriving early. What scales the band with depth is WHO
    -- is in it (models/warband.lua reads Class.gateLevel), not whether it may appear at all.
    depth = 1,
    composition = function(ctx)
        local list = {
            "character_forsworn_captain", -- setup: the oath that armours the rank
            "character_forsworn_knight",  -- payoff: enormous inside the formation, ordinary outside it
            "character_warden",           -- multiplier: the flank is where the answer was
            "character_forsworn_knight",
        }
        for _ = 1, math.floor((ctx.depth or 1) / 4) do list[#list + 1] = "character_forsworn_knight" end
        return list
    end,
}
