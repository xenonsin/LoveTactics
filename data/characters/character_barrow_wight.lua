-- THE BARROW-WIGHT: the floor's wraith. Its own body -- there is no living blueprint under a wight -- and
-- Tolkien's barrow-wights are the source: they do not kill you, they lay you out for the grave. Reviewed
-- 2026-09-25 ("The Dead Hand"); its Gilded touch was denied as strange and became Sleep.
--
--   HALF HERE   a physical weapon blow has half its chance to hit it, unless it is lit -- Witchlight, or a
--               foe's carried lantern. Spells and holy damage find all of it (trait_half_here).
--   THE DRIFT   it moves through rock and through bodies (the Barrow-Shade: `flying` + phasing).
--   THE TOUCH   a cold touch that puts a body to Sleep, on a two-turn cooldown -- and the ghouls hunt the
--               sleeping first. That pairing is the Charnel's whole fight.
--
-- THE COUNTER IS LIGHT OR MAGIC: a flare, a caster, a priest. The half-miss is a rule, not a hide, so its
-- slash/pierce/impact lines stay at zero and the innate line is only the dark it is made of.
return {
    name = "Barrow-Wight",
    race = "undead",
    tier = 2,
    sprite = "assets/chars/barrow_wight.png",
    archetype = "aggressive",
    stats = {
        health = 32, mana = 30, stamina = 14,
        staminaRegen = 2,
        damage = 6, magicDamage = 14,
        defense = 0, magicDefense = 8,
        movement = 5,
        speed = 5,
        skill = 4, luck = 3,
    },
    resist = { dark = 3, holy = -6 },
    startingItems = {
        "ability_wight_touch", "utility_wight_body", false,
        false,                 false,                false,
        false,                 false,                false,
    },
    drops = { "utility_wights_shroud", "ability_through_the_rock", "ability_barrow_touch" },
    defaultAction = "ability_wight_touch",
    ai = {
        { priority = "high", act = "cast", item = "ability_wight_touch",
          when = { subject = "any_foe", test = "exists" } },
    },
}
