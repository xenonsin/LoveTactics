-- VIRTUE · both · rare. Every ally mends a little each turn of every fight. A battleStart boon
-- (status_regen) laid on the WHOLE party, not just the line -- the rare-shelf sustain that turns a long
-- run of attrition survivable. Reads as "both" so a Reliquary or a Fence can offer it either way.
return {
    name = "Reliquary Draught",
    blurb = "Every ally regenerates a little each turn, in every fight this quest.",
    tier = "rare", alignment = "virtue", affinity = "both", weight = 1,
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.party) do ctx.grantBoon(c, "status_regen") end
    end,
}
