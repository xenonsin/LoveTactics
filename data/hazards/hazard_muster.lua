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
    description = "Mustered ground: allies stand braced in it, and enemies stand open.",
    sprite = "assets/hazards/muster.png",
    tags = { "banner" },
    duration = 6,
    disposition = "neutral", -- it draws the owner in and pushes the foe out; neither reading is right
    onEnter = function(ctx)
        if ctx.isAlly(ctx.unit) then
            ctx.applyStatus(ctx.unit, "status_heroism")
        else
            ctx.applyStatus(ctx.unit, "status_exposed")
        end
    end,
}
