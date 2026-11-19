-- THE CLAN STANDS: the Oni General's organ (trait_the_clan_stands, read by Trait.trySurvive). Approved
-- 2026-09-27 ("The Oni of Wrath", round 2). Bound and unstealable. Reaches only the oni within 2 of the General
-- since 2026-11-19 (the creature identity pass; the trait says why).
return {
    name = "The Clan Stands",
    description = "While you stand, an oni of your side within 2 that would fall stays up at 1 health for one more action, once.",
    flavor = "No oni has ever died first while the General watched. They have all died second.",
    sprite = "assets/items/utility_the_clan_stands.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_clan_stands" },
}
