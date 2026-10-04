-- SLOTH'S OGRE, rung 3 (approved 2026-10-04, "Sloth's Bestiary", slice B): one body on the meltwater approach.
-- Built on the reference 2x2 body (character_ogre, which stays the footprint fixture the specs use, and the War
-- Ogre's base) as a body of its own, so neither of those moves.
--
-- CAN'T BE BOTHERED (ability_cant_be_bothered): an ogre never walks (`movement = 0`). Each turn it picks up the
-- nearest body beside it, on either side, and throws it up to 4 tiles at the company's body farthest away; both take
-- impact damage, and the thrown body lands beside its target. With nobody beside it, it tears up a slab of ice and
-- throws that, for half. With a foe beside it and nobody in reach to throw it at, it punches.
--
-- The counter is the review's: never end a turn beside it, or it throws your front-liner at your healer; lure its
-- own escort beside it and it throws them at you, hurting its own side; kill it from range. A beast, so no shelf:
-- it drops Ogre's Heave (Barbarian).
return {
    name = "Ogre",
    race = "beast",
    tier = 3,
    sprite = "assets/chars/sloth_ogre.png",
    footprint = { w = 2, h = 2 },
    archetype = "aggressive",
    stats = {
        health = 136, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 18, magicDamage = 0,
        defense = 9, magicDefense = 3,
        movement = 0, -- it can't be bothered
        speed = 1,
        skill = 4, luck = 5,
    },
    -- The ogre's own hide (character_ogre): four tiles of animal, and a spear is the weapon for a large target.
    resist = { impact = 4, pierce = -4 },
    startingItems = { "weapon_stone_fists", "ability_cant_be_bothered" },
    drops = { "ability_ogres_heave" },
    defaultAction = "weapon_stone_fists",
}
