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
    },
    startingItems = { "weapon_gilt_maw" },
    defaultAction = "weapon_gilt_maw",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
