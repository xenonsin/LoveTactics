-- Brimming Chalice: the priest's Overflow multiplier (docs/engines.md). Healing the bearer casts that
-- goes past full is not lost: it becomes barrier on the body it was cast on (trait_brimming), the same
-- pooled barrier the knight's Rampart builds. A healer with nothing to heal still has a turn.
--
-- Reworked from the Warding Chasuble (2026-11-18), whose every heal also laid a whole-blow Physical
-- Barrier. That made it the best multiplier on the shelf for doing nothing new; this one pays only for
-- the overflow. The Surfeit Heart (the Gorged's drop) stays as the patient-side version. The id stays
-- for saves and the Exorcist's drop list.
return {
    name = "Brimming Chalice",
    description = "Healing past full becomes barrier on the healed ally.",
    flavor = "The Cathedral fills it to the brim at every service, and never once spills it.",
    sprite = "assets/items/armor_warding_chasuble.png",
    type = "utility",
    tags = { "holy" },
    class = "priest",
    unlockLevel = 12,
    traits = { "trait_brimming" },
    bonus = { magicDefense = 2 },
}
