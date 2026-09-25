-- Mithril: the Mithril Shirt's flag (data/items/armor/armor_mithril_shirt.lua). No hook: Combat.critChance
-- answers 0 against a bearer, and the forced-critical check on the blow is refused the same way, so the
-- forecast and the swing agree that no blow against it is a critical.
return {
    name = "Mithril",
    description = "No blow against you is ever a critical.",
    critProof = true,
}
