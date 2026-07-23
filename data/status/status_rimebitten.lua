-- Rimebitten: the cold is in the wound, and every fresh blow reopens it. Any damage that lands on the
-- bearer -- from anyone, of any kind, including a poison tick or a fire it walked into -- is followed
-- by a flat bite of ice on top (Status.onDamaged, the hook Sleep uses to wake itself).
--
-- A MULTIPLIER ON FOCUS, which is a thing this game's debuffs did not previously have. Burn and Poison
-- pay out on the CLOCK: they are worth the same whether the party ignores the target or piles onto it.
-- This pays out on ATTENTION. One archer plinking a rimebitten foe is barely worth the cast; four
-- characters converging on it is where the number comes from. It is the mage's contribution to a kill
-- the mage is not personally making, which is a role the pride shelf could not previously fill.
--
-- Deliberately flat rather than a share of the triggering hit. A percentage would scale with the
-- greatsword and vanish beside the dagger, which is backwards -- the whole appeal of this effect is
-- that it rewards the CHEAP repeated hit, and a flat bite is worth proportionally most to exactly
-- those. It also keeps the arithmetic something a player can do at the table: four hits, four bites.
--
-- Raw, so armor does not soften it twice: the blow that triggered it has already been mitigated, and
-- the ice is a consequence of the wound rather than a second attack on the breastplate.
return {
    name = "Rimebitten",
    abbr = "Rime",
    description = "Rimebitten: takes extra cold damage every time anything hits it.",
    color = { 0.62, 0.84, 0.94 }, -- badge tint (pale ice)
    duration = 12,                -- ~2.5 turns: a window your side is meant to spend
    magnitude = 4,                -- the bite per hit; the granting spell raises it per level
    debuff = true,
    resistible = "magical",
    onDamaged = function(ctx)
        -- Only a real wound reopens it: a blow fully eaten by a barrier, dodged, or banked into a
        -- Sealed Hour never reaches this hook at all (see Combat.dealFlatDamage's early returns), and a
        -- 0 that somehow did should not conjure a bite out of nothing.
        if (ctx.amount or 0) <= 0 then return end
        ctx.damage(ctx.unit, ctx.magnitude or 4, { "ice", "magical" }, { raw = true })
    end,
}
