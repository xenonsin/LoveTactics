-- A drilled line-soldier: the bearer stands stronger the more allies flank it, gaining defense and
-- magic defense for each ally standing orthogonally adjacent. A wall in a huddle, exposed alone.
--
-- MEASURED CONTINUOUSLY, which it was not always. This trait used to fire `onCombatStart` and bank the
-- result through ctx.addBonus, and carried an apology in this header for it: *"Measured once, when the
-- line is set (there is no per-turn hook), so position at the opening bell is what counts."* That was
-- honest about the plumbing and wrong about the soldier. It meant a line-soldier kept a full
-- formation's defense while standing alone over its own dead -- and got nothing for closing ranks,
-- which is the one thing a drilled line actually does.
--
-- It is the trait that named the gap, so it is the trait the gap was closed for. `live` (see
-- Trait.liveBonus, folded into Combat.flatStat) reads the board on every stat read, so the bonus rises
-- as the rank forms and falls as it breaks. The numbers are unchanged -- 2 defense and 1 magic defense
-- per neighbour -- because what was wrong was never the magnitude, it was the tense.
--
-- Two things that follow, and are meant to:
--
--   * IT IS A NERF to whoever carries it, and a deliberate one. The old reading paid out at the opening
--     bell and never took it back; this one is a live claim about a line that can break. A formation
--     charm should be worth most while the formation exists.
--   * NO ctx.addBonus. That helper writes `unit.bonus`, the permanent per-battle bucket -- and flatStat
--     already sums that bucket alongside this live read. Banking here as well would count every
--     neighbour twice. `live` returns a table and touches nothing; it must stay that way, because both
--     damage previews and the inventory tooltip call flatStat on every hover frame.
return {
    name = "Formation Fighter",
    description = "Gains defense for each ally standing beside it, as the line forms and as it breaks.",
    live = function(ctx)
        local n = ctx.count(1, "ally")
        if n == 0 then return nil end
        return { defense = 2 * n, magicDefense = 1 * n }
    end,
}
