-- Muster: the ground a Muster Cuirass holds. It does two opposite things at once, sorted by whose feet
-- are on it -- allies standing in it are braced (Heroism's steadiness), enemies standing in it are
-- Exposed. One zone, two effects, decided by `ctx.isAlly`.
--
-- That double reading is what makes it worth a whole item rather than being two smaller ones. A pure
-- buff aura rewards clumping up, which this game already rewards plenty; a pure debuff aura rewards
-- shoving into the enemy, which is the knight's job anyway. Doing both means the cuirass wants the two
-- lines TOUCHING -- your people inside the square, theirs inside it too -- which is a genuinely
-- uncomfortable place to want to be, and exactly where a knight is supposed to want to be.
--
-- Ground that walks (Combat.layIncense), so the square is wherever its wearer is standing, and the
-- wearer is by definition in the middle of it. There is no version of this item that is safe to use.
return {
    name = "Muster",
    description = "Grants Heroism to allies in it; inflicts Exposed on foes.",
    tags = { "banner" },
    duration = 6,
    disposition = "neutral", -- it draws the owner in and pushes the foe out; neither reading is right
    -- ...but the EYE reads it as the wearer's own ground: a knight musters their line. `fx.valence`
    -- overrides the neutral disposition for the field colour only (ui/field_fx.lua), so the cuirass
    -- draws the green rising chevrons of a buff rather than the orange of a threat. The AI still plans
    -- against the neutral disposition above; this is a view hint and nothing more.
    fx = { valence = "friendly" },
    onEnter = function(ctx)
        if ctx.isAlly(ctx.unit) then
            ctx.applyStatus(ctx.unit, "status_heroism")
        else
            ctx.applyStatus(ctx.unit, "status_exposed")
        end
    end,
}
