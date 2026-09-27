-- THE SURFEIT HEART's rule (data/items/utility/utility_surfeit_heart.lua). Healing past the bearer's max health is
-- not lost: it is banked as Surfeit, a shield of up to 25% of max health, and the next hit breaks it
-- (Combat.bankSurfeit in the heal funnel, Combat.soakIntoSurfeit in the damage funnel). The `surfeit` field is the
-- cap, as a share of max health; a granter may name another (Trait.param).
return {
    name = "Surfeit Heart",
    description = "Healing past max health becomes a shield of up to 25% of max. The next hit breaks it.",
    surfeit = 0.25,
}
