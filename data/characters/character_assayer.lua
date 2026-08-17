-- An assayer: the Greed circle's specialist, and the body whose difficulty the player sets.
--
-- It gains damage for the coin your company is carrying (data/traits/trait_assayed.lua), read live -- so
-- a run that has been hoarding meets a harder floor than one that spent at the Forge, and the chitters
-- robbing you during the fight lower the number as they go.
--
-- The counterplay is not tactical at all. It is to have spent, three stops earlier, which is the only
-- mechanic in the descent whose knob is that far upstream. Greed is the sin that punishes keeping things.
return {
    name = "Assayer",
    kind = "demon",
    tier = 2,
    sprite = "assets/chars/assayer.png",
    stats = {
        health = 60, mana = 20, stamina = 20,
        staminaRegen = 2,
        damage = 9, magicDamage = 6, -- the base is modest; your purse is the rest of it
        defense = 6, magicDefense = 8,
        movement = 4,
        speed = 4,
    },
    startingItems = { "weapon_cutpurse_nip", "utility_assay_scales" },
    defaultAction = "weapon_cutpurse_nip",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
