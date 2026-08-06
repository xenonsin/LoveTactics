-- Against The Odds: the Champion stands harder the worse the odds are. Defense and speed for each
-- living enemy standing adjacent, read off the board RIGHT NOW.
--
-- A LIVE PASSIVE, which is the point of it. Every other trait in this folder banks its result when an
-- event fires -- struck, cast, killed -- and that shape cannot say this one: "the more of them there
-- are around me" is a claim about how the board stands, and a board changes twice a turn. So this
-- declares `live` (Trait.liveBonus, folded into Combat.flatStat beside the equipment and status
-- bonuses) and is recomputed on every read. Walk the enemies off and it falls back down; that
-- falling back is not a drawback of the mechanism, it is the mechanic.
--
-- SPEED IS THE INTERESTING HALF. Defense alone would make a surrounded Champion merely durable, which
-- the knight's shelf already sells five ways. Speed is initiative -- the one currency nobody gets back
-- (docs/classes.md) -- so a Champion who lets itself be surrounded ACTS more often for it, and that
-- turns "I am in trouble" into "this is my turn to work". Wading in is supposed to be the correct
-- play, not the brave one.
--
-- Counted at radius 1, which in this codebase is ORTHOGONAL: Combat.unitsNear measures through
-- Combat.cellGap, and that is a Manhattan distance, so the four neighbours pay and the corners do not.
-- Uncapped deliberately -- four adjacent enemies is a body completely enveloped, and a game where that
-- is the Champion's best moment is a better game than one where it is merely survivable. On a board of
-- MAX_FIELD 4 a side, being surrounded by four means the entire enemy field is committed to you.
return {
    name = "Against The Odds",
    description = "Gains defense and speed for each enemy standing beside it, moment to moment.",
    live = function(ctx)
        local n = ctx.count(1, "enemy")
        if n == 0 then return nil end
        return { defense = 2 * n, speed = 1 * n }
    end,
}
