-- Saber, the fighter companion (patience) -- the second recruit and the boss of the first Colosseum
-- bout (data/quests/arena_debut.lua). See docs/story.md, "The other seven": every companion is a
-- woman with a gender-neutral name, and the virtue is hinted, never labeled -- a saber is her blade,
-- and in another tongue (sabr) it is patience itself.
--
-- She is the arena's gatekeeper, and the debut bout is secretly her own audition: a seasoned
-- gladiator who has watched the Colosseum and its patron, Ira (see character_general_wrath.lua),
-- devour fighter after fighter, and who will not be eaten. She fights every newcomer waiting for the
-- pair who can beat her -- and her quarrel with the patron beneath the sand is the whole wrath line.
-- Beat her and she joins; the fighter you best in sport here is the foil to the general you kill in
-- earnest at the line's end.
--
-- `boss = true` gives the debut fight its integrity (immune to execute + Charm so an early party
-- can't trivialize her); it is inert once she is an ally, whom nothing targets that way. Her kit is
-- burst-and-finish -- the greatsword's raw damage -- which is exactly the counterplay to Ira, whose
-- rule rewards a long trade. A potion beside it keeps her patient: she does not have to win fast.
return {
    name = "Saber",
    sprite = "assets/chars/saber.png",
    portrait = "assets/portraits/saber.png", -- large VN portrait for conversations (falls back if missing)
    class = "fighter",
    boss = true,
    stats = {
        health = 120, mana = 0, stamina = 80,
        staminaRegen = 2,
        damage = 22, magicDamage = 0,
        defense = 11, magicDefense = 6,
        movement = 3,
        speed = 4, -- quick for a greatsword: she picks her moment
    },
    -- The First Motion is the build-around, `bound` in the centre exactly as Rowan's Aegis is
    -- (data/items/weapon/weapon_first_motion.lua). It is the counterplay to Ira stated as arithmetic:
    -- Ira scales as her own health falls, Saber scales with her target's. A player who fields Saber
    -- has been holding the answer to the general since the debut bout.
    startingItems = {
        false, "consumable_healing_potion", false,
        false, "weapon_first_motion",       false,
        false, false,                       false,
    },
    defaultAction = "weapon_first_motion",
}
