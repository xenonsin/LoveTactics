-- THE GILT WYRM: Greed's mythic, and the circle's dragon.
--
-- A wyrm grown into its hoard until the two stopped being separable -- gold-scaled, immovable, and
-- taking coin off everything it catches. It is the oldest fantasy image in the genre and it is here
-- because Greed had earned it: a body that IS the pile it is guarding.
--
-- NOT character_wild_wyrm, which is a shape a druid wears (Mira's bound relic) rather than a body that
-- fights as itself. Fielding a worn shape as an enemy is the mistake this whole pass removed from
-- Gluttony's honour-guard slot; the druid's wyrm stays hers.
--
-- FOOTPRINT 2x2. On the `caverns` carve -- a warren -- a four-tile body is a door that closed, which is
-- what an apex should mean on ground that has doors.
return {
    name = "The Gilt Wyrm",
    kind = "beast",
    tier = 3,
    sprite = "assets/chars/the_gilt_wyrm.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 146, mana = 0, stamina = 24,
        staminaRegen = 2,
        damage = 16, magicDamage = 0,
        defense = 14, magicDefense = 7, -- scaled in coin
        movement = 2, -- it does not leave the pile. It is most of the pile
        speed = 2,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 4, luck = 5,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Gold-scaled to the point where the hoard and the wyrm are the same object.
    --   Gold is soft, and gold conducts. Both of those are ways of saying the same thing about a hammer.
    resist = { slash = 4, pierce = 2, impact = -6, lightning = -4 },
    startingItems = { "weapon_gilt_maw" },
    defaultAction = "weapon_gilt_maw",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
