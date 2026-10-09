-- THE ADVENTURER KNIGHT ("The Rift's Adventurers", approved 2026-10-09; models/adventurers.lua). A
-- race-free body: fielded as `character_adv_knight@<race>`; `race` is only the class's first leaning
-- race, so the bare blueprint loads.
--
-- The knight decides where you stand, which is what Hold and Loose, the Killing Ground and Stripped Bare
-- all ask of it: Provoke taunts every adjacent foe onto it, and the Mailpiercer Halts the body behind,
-- so somebody is held still for the hunter and the rogue. The Mailpiercer is the knight's own Halt.
-- Provoke is NOT -- the knight shelf carries no taunt at all, so it is borrowed from the Champion, the
-- crossing a knight grows into; the departure is reported, not hidden.
return {
    name = "Knight",
    race = "human",
    tier = 1,
    adventurer = true,
    class = "knight",
    sprite = "assets/chars/rowan.png",
    archetype = "defensive",
    stats = {
        health = 30, mana = 15, stamina = 18,
        staminaRegen = 2,
        damage = 8, magicDamage = 4,
        defense = 6, magicDefense = 4,
        movement = 4,
        speed = 3,
        skill = 3, luck = 2,
    },
    startingItems = {
        "weapon_mailpiercer", "ability_provoke", "armor_buckler",
        "armor_chainmail", "consumable_healing_potion",
    },
    defaultAction = "weapon_mailpiercer",
    signatureWeapon = "weapon_mailpiercer",
    signatureAbility = "ability_provoke",
    ai = {
        -- Taunt whoever has come close, and stand braced for it.
        { priority = "high", act = "cast", item = "ability_provoke",
          when = { subject = "any_foe", test = "within", value = 1 } },
        -- Then hold one of them still with the thrust.
        { priority = "normal", act = "attack", item = "weapon_mailpiercer",
          when = { subject = "any_foe", test = "lacks_status", value = "status_halted" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
