-- THE GOBLIN KING: the elite of Wrath's goblins, in his Rigged Hall (round 1 picked the Rigged Hall over Temper;
-- round 2 added Toss a Goblin and the Cage Lever, and cut the Gong and Off the Throne -- 2026-09-26, "The Goblins
-- of Wrath").
--
-- HE NEVER LEAVES HIS THRONE (movement 0). Each turn he pulls a lever: a row of the hall is marked, and next turn
-- it opens into fire, and anyone on it is downed -- his own court included (the Rigged Hall). His reach is his
-- court: he throws a goblin beside him onto a foe up to five away (Toss a Goblin), and one lever opens a cage and
-- lets a Fanatic loose (the Cage Lever). A puzzle elite on the Coin-Eaters' rule: fatal means downed in a zone you
-- were shown.
--
-- Tier 3, the elite band -- not a boss, so no assassinate mark. He drops the King's Lever, which hurts rather
-- than downs.
return {
    name = "Goblin King",
    race = "goblin",
    tier = 3,
    class = "fighter", -- no discipline: his kit is his throne's, and a claimed discipline must be carried
    sprite = "assets/chars/goblin_king.png",
    archetype = "defensive",
    stats = {
        health = 150, mana = 0, stamina = 40,
        staminaRegen = 5,
        damage = 15, magicDamage = 0,
        defense = 6, magicDefense = 6,
        movement = 0, -- the throne
        speed = 4,
        skill = 6, luck = 4,
    },
    startingItems = {
        "weapon_iron_hammer",   "ability_rigged_hall", "ability_toss_a_goblin",
        "ability_cage_lever",   false,                 false,
        false,                  false,                 false,
    },
    drops = { "ability_kings_lever" },
    defaultAction = "weapon_iron_hammer",
    signatureWeapon = "weapon_iron_hammer",
}
