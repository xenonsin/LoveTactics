-- Acedia's serjeant, and the wall in front of her. Where the ordinary Forsworn Knight punishes the
-- huddle her oath forces (data/characters/character_forsworn_knight.lua), the captain holds the
-- huddle SHUT: the Oathkeeper's Defend brace covers every adjacent ally, so a line of them is a door.
--
-- The bitter joke is that this is the Bastion's own rank-4 doctrine, executed properly, by deserters.
-- They are better at holding a line than anyone the player can buy it from -- which is the argument
-- the whole line has been making, standing on the board in armor.
--
-- A SENTINEL (data/disciplines/sentinel.lua), and the Forsworn's Elite rung (docs/bestiary.md). She
-- already had the claim in her header -- "covers every adjacent ally" is Intercept stated word for
-- word -- and carried two items, which is a Line kit. The Warden's Oath is that sentence made
-- mechanical: the first hit each turn on anyone beside her lands on her instead, with no turn spent
-- and no brace to hold. The Lent Aegis is the same oath paid the other way, stripping her own guard to
-- put it on somebody else, which is what a serjeant standing in front of a general is for.
--
-- The stat line is untouched. She is harder to get past than she was, but only because of two items
-- the player can take off her and hold -- both priced, both unbound, both Sentinel stock she cannot
-- shop for until the Bastion opens that shelf.
return {
    name = "Forsworn Captain",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/forsworn_captain.png",
    class = "knight",
    discipline = "sentinel",
    stats = {
        health = 98, mana = 0, stamina = 15,
        staminaRegen = 2,
        damage = 17, magicDamage = 0,
        defense = 20, magicDefense = 10,
        movement = 2,
        speed = 2,
    },
    -- The 3x3 loadout grid (row-major); false = an empty cell. Mace and shield are the doctrine she
    -- deserted with; the Oath and the Aegis are what she does with it that the Bastion no longer can.
    startingItems = {
        "weapon_iron_mace",   "armor_oathkeeper_shield", false,
        "armor_wardens_oath", "utility_lent_aegis",      false,
        false,                false,                     false,
    },
    defaultAction = "weapon_iron_mace",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua).
    signatureWeapon  = "weapon_iron_mace",
    signatureAbility = "armor_wardens_oath",
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling,
    -- ahead of the posture's ordinary "hit whatever is in reach".
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
