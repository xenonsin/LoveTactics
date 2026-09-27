-- THE BLOOD COUNTESS, rung 3: Wrath's seat elite (Wrath's vampires, rounds 2-3, approved 2026-09-27). Bathory's
-- bath, made a rule rather than a story: a Blood Basin stands in the middle of the board, and every point of Bleed
-- damage taken anywhere fills it. When it is full she BATHES at the top of her next turn, from wherever she stands
-- -- healed to full, +2 Speed and +20% Damage for the rest of the fight, to two baths -- and it fills again
-- (models/basin.lua).
--
-- SHE FIGHTS TO MAKE YOU MOVE. Her hand opens a vein and then throws you two tiles (weapon_countess_hand), so the
-- first thing every wound does is bleed into her basin; her Familiars and Blood-Ghouls keep the wounds open. The
-- answers are to break the basin, or to stand still and starve it.
--
-- A title and not a name: she is met on every visit (floors re-arm), so she is a rule anybody could fall into.
-- A human fighter on the fighter table, carrying the Duelist's Poise so the discipline it claims is on it.
-- Drops the Waltz and the Iron Maiden.
return {
    name = "The Blood Countess",
    race = "human",
    tier = 3,
    class = "fighter",
    discipline = "duelist",
    vampire = true,
    sprite = "assets/chars/the_blood_countess.png",
    archetype = "aggressive",
    stats = {
        health = 100, mana = 0, stamina = 30,
        staminaRegen = 5,
        damage = 12, magicDamage = 0,
        defense = 4, magicDefense = 6,
        movement = 4,
        speed = 5,
        skill = 8, luck = 7,
    },
    startingItems = {
        "weapon_countess_hand", "utility_the_bath",  "utility_duelists_poise",
        "ability_wing_swap",    "ability_feed",      false,
        false,                  false,               false,
    },
    drops = { "ability_the_waltz", "armor_iron_maiden" },
    defaultAction = "weapon_countess_hand",
    signatureWeapon = "weapon_countess_hand",
}
