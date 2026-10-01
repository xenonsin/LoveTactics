-- Angel: the choir of Pride's spire, and the circle's second race. Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- INCORRUPTIBLE. Pride's angels are the ones who never fell, and they know it: nothing from outside the choir lands
-- on one. No debuff a foe lays -- no Root, no Stun, no Charm, no Burn -- and no push or pull. What its OWN side hands
-- it still lands, and that is the whole of how the choir works: the Herald's hymn Blesses, the Virtue Wards, and the
-- company cannot answer either by laying something back. So the lever a company holds is damage and position, never
-- control: kill the one singing, and stand where the Throne's light is not.
--
-- WINGED: every tile costs one, and no ground is impassable (the `flying` tag, Combat.isFlying) -- which also means
-- an angel forfeits the tile it is over (no cover, no vantage), the trade every flier in the game makes.
--
-- HOLY AND DARK. Light turns aside on light, and the dark it never learned goes straight in. The review asked for
-- holy +4; a race is written to the LOWEST rung that wears it (tests/race_spec.lua), and the Herald is chaff, whose
-- budget is 2 -- so holy is +2 and the dark line keeps the full -4 the weakness budget allows.
--
-- The stat line is empty. The race is a rule, and the rule is the point.
--
-- NOT PLAYABLE (approved): no company hires an angel.
return {
    name = "Angel",
    description = "The choir that never fell. Nothing from outside it lands on an angel, and it flies.",
    kind = "humanoid",
    resist = {
        holy = 2,  -- light on light
        dark = -4, -- the one thing it never learned to answer
    },
    grants = { "utility_angel_blood" },
    playable = false,
}
