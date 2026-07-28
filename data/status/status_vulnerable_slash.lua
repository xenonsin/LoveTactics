-- Vulnerable: Slash -- the guard is beaten open, and every edge that follows finds the gap. A flat
-- pre-mitigation bonus to any `slash`-tagged hit that lands on the bearer (`vulnerable`, folded into
-- Combat.mitigatedDamage exactly as Wet's lightning weakness and Exposed's opening to pierce are). It
-- does nothing whatever on its own.
--
-- ONE TAG, and that narrowness is the design (the case Exposed argues in full): a vulnerability to
-- everything is just a damage buff painted on the enemy, but a vulnerability to one hit tag is a
-- question asked of the party's whole loadout -- worth nothing beside three maces, and a great deal
-- beside a line of swords, axes and greatswords. Slash is the commonest physical tag in the game, and
-- until this the only one nothing at all could amplify. See docs/vulnerability.md for the family.
return {
    name = "Vulnerable: Slash",
    abbr = "Vsl",
    description = "Laid open: takes extra damage from slashing hits.",
    color = { 0.714, 0.737, 0.776 }, -- badge tint (bared steel-grey)
    fx = { field = true },   -- draws ground under the afflicted body (a debuff: the hostile look, ui/field_fx.lua)
    duration = 12,           -- ~2.5 turns at Status.TICKS_PER_TURN: a window your slashers are meant to spend
    debuff = true,           -- removable by Cure / Panacea
    vulnerable = { slash = 8 },
}
