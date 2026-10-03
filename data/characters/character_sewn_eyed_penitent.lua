-- THE SEWN-EYED PENITENTS: one of Envy's one-off families, on the waste's seat ("Envy's Bestiary", 2026-10-03, slice
-- C). From Dante's terrace of the envious, whose eyes are sewn shut with iron wire.
--
--   HUNTS BY EAR  blind, they hunt by sound: they always strike the last of the company to act, and Invisible,
--                 illusions and Blind mean nothing to them (utility_sewn_eyes, AI.preempt)
--
-- THE COUNTERPLAY, STATED: order your turns. Act last with whoever should take their blows -- a Shade's hiding and
-- a Mirage's illusions mean nothing to them.
--
-- Undead: shades of the dead on a terrace of purgatory, so Grave-Cold comes with them and a heal burns them. Bodies
-- worn thin by penance: a blade finds bone, a club finds nothing to break that is not broken.
return {
    name = "Sewn-Eyed Penitent",
    race = "undead",
    tier = 2,
    sprite = "assets/chars/sewn_eyed_penitent.png",
    stats = {
        health = 46, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 10, magicDamage = 0,
        defense = 3, magicDefense = 3,
        movement = 4,
        speed = 4,
        skill = 6, luck = 2,
    },
    resist = { slash = -2, impact = 2, dark = 2 },
    startingItems = {
        false,                      false,               false,
        "weapon_penitents_scourge", "utility_sewn_eyes", false,
        false,                      false,               false,
    },
    defaultAction = "weapon_penitents_scourge",
    -- ITS OWN PIECE (docs/drops.md): the wire, carried.
    drops = { "utility_iron_thread" },
    archetype = "aggressive",
}
