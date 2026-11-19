-- SHIELDED: a bow of the dead company, standing under its knights' guard (2026-11-19, the creature identity
-- pass; data/traits/trait_the_old_company.lua). Every blow that reaches it is halved
-- (Status.damageTakenScale, applied after armour and resistance, as On the Wing is), and it holds for exactly
-- as long as a knight of the same company is standing -- the trait lays it, refreshes it and lifts it, so
-- the badge on the archer is the board telling the player which body to kill FIRST.
--
-- Not a debuff, and nothing a Cure would lift: it is a fact about the knights, so the answer is the knights.
return {
    name = "Shielded",
    abbr = "Shd",
    description = "Shielded: takes half damage while a Skeleton Knight of its company stands.",
    color = { 0.690, 0.680, 0.600 }, -- badge tint (old bone and older iron)
    duration = 999,
    hideDuration = true,
    damageTakenScale = 0.5,
}
