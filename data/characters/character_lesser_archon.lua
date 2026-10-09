-- THE LESSER ARCHON: the court's filler, on the Crown's floor ("The Crown's Bestiary", slice A, 2026-10-09). A robed
-- soldier of the court, fully humanoid -- the author's note on every Archon: rank shows in the face and the robe.
--
--   MANA EDGE     its blade is cut from its own mana, so its blows land on Magic Defense, not Defense
--                 (weapon_mana_cut_blade, a `magical` blade)
--   SPIRIT BODY   the race: felled, its wisp walks back to raise it (data/races/archon.lua)
--
-- HOW YOU BEAT IT, the review's own: your plate does nothing here. Wear a magic ward, or put your spell-hardened
-- bodies in front.
--
-- ON THE PRIEST TABLE, like the whole court, and it was measured into it. Its blade scales on Magic Damage, which the
-- classless fallback never grows; the mage table does, but it also grows Defense a point a level, and at the floor's
-- level 35 that made a chaff body plate-proof -- the Lower Court ran 38 unit-turns against the skirmish budget of 22.
-- The priest table grows the blade and the ward and leaves the body soft to steel, which is the court the review
-- describes. The low base health is the same measurement: a body that is raised once is two bodies' worth of turns.
--
-- It drops the Mana Edge, a Battlemage's.
return {
    name = "Lesser Archon",
    race = "archon",
    tier = 1,
    class = "priest",
    sprite = "assets/chars/lesser_archon.png",
    archetype = "aggressive",
    stats = {
        health = 10, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 4, magicDamage = 7,
        defense = 2, magicDefense = 2, -- 4 after the race
        movement = 4,
        speed = 4,
        skill = 4, luck = 3,
    },
    startingItems = {
        "weapon_mana_cut_blade", false, false,
        false,                   false, false,
        false,                   false, false,
    },
    drops = { "utility_mana_edge" },
    defaultAction = "weapon_mana_cut_blade",
    signatureWeapon = "weapon_mana_cut_blade",
}
