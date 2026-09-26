-- TARNISHED: rust on a WEAPON, carried by the one who swung it. Laid by the Rust Mite's hide
-- (trait_rust_hide) and the company's Rustcoat on any weapon that strikes them in melee: that weapon deals
-- 2 less damage for the rest of the fight, stacking to -6. Reviewed 2026-09-25 ("The Coin-Eaters").
--
-- PER WEAPON, and that is the whole mechanic. The stacks live on the instance keyed by the item that
-- struck (`rust`), and Status.tarnishOn reads them per blow -- so the same hand's spells, bow, fists and
-- other blades are untouched. The answer to a mite is WHAT you hit it with.
--
-- Not a debuff: rust is not something a Cure washes off, and a fight-long property of the gear is not a
-- condition of the body. The badge counts every stack on the bearer; the tooltip's damage line names the
-- one weapon it applies to.
return {
    name = "Tarnished",
    abbr = "Rust",
    description = "Rust on a weapon: each stack lowers that weapon's damage by 2, up to 3 stacks.",
    color = { 0.62, 0.36, 0.22 }, -- badge tint (rust)
    duration = 999,
    hideDuration = true,
    magnitude = 1,
    perStack = 2,
    maxPerWeapon = 3,
}
