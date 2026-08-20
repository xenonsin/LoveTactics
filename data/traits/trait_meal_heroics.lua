-- Heroics: the Cafe's kitchen skill for The Last Cup. A body running on it hits far harder
-- once it is down past half its health.
--
-- Monster Hunter's Felyne Heroics, imported almost unchanged, because the thing it does to how you play
-- survives the change of genre exactly. It is the one buff that rewards being in trouble: a hunter who
-- is nearly dead is normally playing to not die, and Heroics makes those minutes the most dangerous
-- ones on the board. The board here has fewer of them -- four bodies, not one -- which if anything
-- sharpens it, since it fires for whichever of the four is worst off rather than for you alone.
--
-- A LIVE PASSIVE (Trait.liveBonus, folded into Combat.flatStat), and it must be: the thing it measures
-- moves both ways. Heal the member and the edge should go with it. A banked version would pay the whole
-- company forever for one bad turn in the first fight of the quest.
--
-- A THRESHOLD, NOT A RAMP. The magnitude does not scale with how nearly dead you are -- it is off above
-- half and full below it. A ramp reads as a slot machine on a board where every other number is exact,
-- and, worse, would make each point of incoming damage a small buff: the correct play becomes standing
-- in the fire, which is a different game than the one this is meant to sharpen.
--
-- Cast in DAMAGE AND MAGIC DAMAGE both, at the same figure. A supper does not know what its eater
-- fights with, and a food skill that quietly only worked for the fighters would be the shelf-drift
-- docs/classes.md exists to stop.
return {
    name = "Heroics",
    description = "Increase damage and magic damage by 6 while below half health.",
    live = function(ctx)
        if ctx.missing() < 0.5 then return nil end
        return { damage = 6, magicDamage = 6 }
    end,
}
