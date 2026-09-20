-- THE GATHERED WEIGHT's rule: the bearer is worth more for every hex they are carrying
-- (data/items/utility/utility_gathered_weight.lua, docs/curses.md).
--
-- A LIVE PASSIVE, which is the only shape that can say this. An item's `bonus` is a static table read
-- once at setup, and a hex count is not static -- it moves when a trap fires, when Let It Spread creeps,
-- when the Cathedral lifts one. `live` is recomputed on every stat read (Trait.liveBonus, folded into
-- Combat.flatStat beside the equipment and status bonuses), so the sheet, the damage breakdown and the
-- forecast all move the moment a binding lands or leaves. Nothing has to be told to refresh.
--
-- IT READS THE BEARER'S OWN GRID and nothing else, which is the whole balance of the counting shelf:
-- the body being paid is the body that cannot move, recovers nothing and has half a pool. Nine cells cap
-- it, and every hexed cell is still an item somebody chose to carry down.
--
-- BOTH DAMAGE STATS, so it pays a swordsman and a caster alike -- the Shaman is hunter x mage and its
-- shelf should not quietly require one half of that. Two apiece is deliberately modest: four hexes is
-- +8, which is a real weapon's worth of attack on a body that has paid four curses for it.
return {
    name = "Gathered Weight",
    description = "Gains attack and magic damage for every hex the bearer is carrying.",
    per = 2,
    live = function(ctx)
        local n = require("models.curse").countOn(ctx.unit and ctx.unit.char)
        if n <= 0 then return nil end
        local per = ctx.def.per or 2
        return { attack = per * n, magicDamage = per * n }
    end,
}
