-- THE THOUSAND-WINGED, rung 3: what the swarm's bats become when four or more stand together at a turn's end
-- (models/swarm.lua). Never fielded -- it is only ever FUSED, minted at the bats' own level with 12 health for
-- every bat in it; the 96 below is the whole swarm of eight, the most it can ever be.
--
-- A vampire (the tag: Grave-Cold and the Thirst), so its bite opens a vein and what it draws resets its Thirst; the
-- bats still flying carry their drinks to it (Blood Courier). Struck to 0 it scatters (utility_thousand_wings): half
-- the bats in it fly out, and the rest are dead. It leaves no corpse and pays no drop -- the bats it was are the
-- opening roster, and they carry the swarm's trophy.
return {
    name = "The Thousand-Winged",
    race = "beast",
    tier = 3,
    vampire = true,
    sprite = "assets/chars/thousand_winged.png",
    archetype = "aggressive",
    stats = {
        health = 96, mana = 0, stamina = 30,
        staminaRegen = 5,
        damage = 11, magicDamage = 0,
        defense = 3, magicDefense = 4,
        movement = 5,
        speed = 5,
        skill = 6, luck = 6,
    },
    -- The bats' hide, all of them at once.
    resist = { slash = 1, pierce = 1, impact = -2 },
    startingItems = {
        "weapon_bat_fangs", "utility_thousand_wings", false,
        false,              false,                    false,
        false,              false,                    false,
    },
    defaultAction = "weapon_bat_fangs",
}
