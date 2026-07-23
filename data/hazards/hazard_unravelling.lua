-- Unravelling: ground where the weave has been picked loose. Anything standing in it is Unravelled --
-- every magical hit that lands on it bites deeper (data/status/status_unravelled.lua).
--
-- An AMPLIFIER rather than a weapon: it deals nothing itself, and a party with no casters in it gets
-- precisely nothing out of the turn spent laying it. That is the whole shape of the alchemist's shelf
-- (docs/classes.md: covets others' power rather than casting any) and it is why this ground belongs to
-- envy rather than to pride. The mage would have made the fire bigger. This makes YOUR fire bigger,
-- and only if you brought one.
--
-- Unsided, and that matters more here than usual: standing your own priest in the unravelling to reach
-- a foe is a real risk, because the enemy caster's bolts are amplified by exactly the same number.
-- Ground that helps whoever uses it best is ground worth thinking about, which is more than can be
-- said for a debuff.
--
-- ZONE-BOUND (the status declares no `lingers`), so it holds only while its victim stands on it. Walk
-- out and you are whole. That is what turns the lens into a POSITIONAL commitment: the alchemist has
-- to keep the fight happening on the tiles they picked.
return {
    name = "Unravelling",
    description = "Picked-loose ground: everything standing in it takes more from magic.",
    sprite = "assets/hazards/unravelling.png",
    tags = { "arcane" },
    duration = 14,           -- ~3 turns for the party's casters to spend
    disposition = "hostile",
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "status_unravelled")
    end,
}
