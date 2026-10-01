-- DJINN FORM: what The Last Lamp makes of its bearer (trait_the_last_lamp). Reviewed 2026-09-30 ("Pride's
-- Bestiary").
--
-- A status rather than a Transform on purpose. A transform takes the body's kit (models/transform.lua), and a
-- company member who caught fire at a third of its health and lost its grid for three turns would be punished by
-- its own charm. This keeps every piece it carries and lays the djinn on top: the magic damage, and the blink the
-- trait reads off this badge while it holds.
return {
    name = "Djinn Form",
    abbr = "Djinn",
    description = "Djinn Form: increases magic damage by 4, and blinks away when a foe comes next to it.",
    color = { 0.420, 0.560, 0.900 }, -- badge tint (lamp smoke)
    duration = 15, -- three turns
    statBonus = { magicDamage = 4 },
}
