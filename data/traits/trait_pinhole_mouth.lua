-- PINHOLE MOUTH: the Hungry Ghost's appetite rebuilt for a person (data/items/utility/utility_pinhole_mouth.lua).
-- Narrower than the ghost's Never Full on purpose: it eats only a FOE's healing, so it never starves the
-- company's own priest.
return {
    name = "Pinhole Mouth",
    description = "Heals that land on foes within 2 of you heal you instead.",
    eatsHeals = true,
    foesOnly = true,
    radius = 2,
}
