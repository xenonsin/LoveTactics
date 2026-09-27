-- THE SWARM FAMILIAR, rung 1: one of the Thousand-Winged's eight bats (Wrath's vampires, round 3; the elite is
-- data/encounters/encounter_wrath_the_thousand_winged.lua). The Familiar's body and bite, with the swarm's rule
-- (utility_the_swarm, models/swarm.lua): at the end of any turn, 4 or more standing together fuse into the
-- Thousand-Winged. It flies to the biggest group of its kin (the gather posture reads `swarms`), and hits what it
-- can reach on the way. Still a Blood Courier: what it drinks goes to the nearest vampire -- the lord, once there
-- is one.
--
-- Its own blueprint rather than the Familiar with a trait bolted on, so the Night Flight's and the Sire's bats do
-- not gather, and so the swarm's drop is on the body that fields it. Drops Swarm Form.
return {
    name = "Swarm Familiar",
    race = "beast",
    tier = 1,
    sprite = "assets/chars/swarm_familiar.png",
    archetype = "gather",
    stats = {
        health = 14, mana = 0, stamina = 16,
        damage = 4, magicDamage = 0,
        defense = 1, magicDefense = 2,
        movement = 6,
        speed = 6,
        skill = 3, luck = 6,
    },
    -- INNATE MITIGATION: the Familiar's -- leather and hollow bone. A club takes it out of the air.
    resist = { slash = 1, pierce = 1, impact = -2 },
    startingItems = { "weapon_bat_fangs", "utility_blood_courier", "utility_the_swarm" },
    drops = { "ability_swarm_form" },
    defaultAction = "weapon_bat_fangs",
}
