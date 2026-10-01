-- THE UNICORN: one of Pride's one-off elites, on the spire's approach ("Pride's Bestiary", 2026-09-30). The
-- myth's beast that only the pure may touch, read as pride: it has decided who is worthy, and it is never
-- wrong about it.
--
--   REJECTS THE UNWORTHY  it cannot be hurt by a body carrying a debuff, a curse or an injury
--                         (trait_rejects_the_unworthy, on its Purity; answered in Status.immuneToDamage)
--   ITS HORN DECIDES      the Spiral Horn's blow inflicts Blighted, a debuff, so every body it strikes is
--                         turned away until somebody Cures it
--   AND CLEANSES          at the end of each of its turns the horn lifts every debuff off its side
--
-- THE COUNTERPLAY, STATED: keep a clean body on it and keep it clean -- Cure the ones it has struck, leave the
-- injured and the hexed on the bench, and spend control on the escort knowing the horn will wash it off.
--
-- ITS ESCORT is a band of Gilded Pages (encounter_pride_the_unicorn). Alone, "cleanses its side" would cleanse
-- only itself, and the pages are Pride's cheapest body: a company that roots and stuns them to work the Unicorn
-- buys exactly one of its turns, which is the horn's half of the rule doing something on the board.
--
-- Its hide takes holy (it is holy) and folds to dark. Tier 3 and `boss`, off the execute and Charm tables like
-- every elite.
return {
    name = "Unicorn",
    race = "beast",
    tier = 3,
    boss = true,
    sprite = "assets/chars/unicorn.png",
    stats = {
        health = 120, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 15, magicDamage = 0,
        defense = 7, magicDefense = 9,
        movement = 5,
        speed = 3,
        skill = 7, luck = 6,
    },
    resist = { holy = 4, dark = -4 },
    startingItems = {
        false,                 false,            false,
        "weapon_spiral_horn",  "utility_purity", false,
        false,                 false,            false,
    },
    defaultAction = "weapon_spiral_horn",
    -- ITS OWN PIECE (docs/drops.md): the horn, cut down for an exorcist.
    drops = { "weapon_horn_of_purity" },
    archetype = "aggressive",
}
