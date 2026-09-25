-- THE KOBOLD SCALE-PRIEST, rung 2: the line's caster and its voice. Approved in round 1 (2026-09-24); its
-- summons changed in round 2 from the Tithe-Call (which hurried gold-carriers) to Dragon's Call.
--
--   BORROWED BREATH   a cone of fire, +3 for each ally beside it -- Pack, on a caster. Break up the huddle.
--   SCALE BLESSING    a kinsman gains Dragonscale, +3 Defense for about two turns
--   DRAGON'S CALL     once a fight, every kobold takes a free step toward the nearest dragon
--
-- A SHAMAN (mage root). Drops Borrowed Breath.
return {
    name = "Kobold Scale-Priest",
    race = "kobold",
    tier = 2,
    class = "mage",
    discipline = "shaman",
    sprite = "assets/chars/kobold_scale_priest.png",
    archetype = "support",
    stats = {
        health = 36, mana = 48, stamina = 12,
        staminaRegen = 2,
        damage = 5, magicDamage = 11,
        defense = 2, magicDefense = 6,
        movement = 4, -- 5 after the race
        speed = 4,    -- 5 after the race
        skill = 5, luck = 5,
    },
    startingItems = {
        "weapon_staff",          "ability_borrowed_breath", "ability_scale_blessing",
        "ability_dragons_call",  false,                     false,
        false,                   false,                     false,
    },
    drops = { "ability_borrowed_breath" },
    defaultAction = "weapon_staff",
    signatureWeapon = "weapon_staff",
    ai = {
        { priority = "urgent", act = "cast", item = "ability_dragons_call",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "high", act = "attack", item = "ability_borrowed_breath",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "normal", act = "support", item = "ability_scale_blessing", targetPref = "nearest",
          when = { subject = "any_ally", test = "lacks_status", value = "status_dragonscale" } },
    },
}
