-- What has been leaning on Highwatch's gate for six weeks, and the mark of slot 1's objective
-- (data/quests/relief_column.lua, `assassinate`). Kill it and the investment comes apart; the
-- besiegers on that mountain are an army only while something is holding them to the rock.
--
-- `holdGround`: it never leaves the gate. That is what makes the final board readable as a siege
-- rather than a brawl -- the thing you have to kill is standing exactly where the wagons need to
-- end up, so breaking the breach and delivering the column are the same tactical problem seen from
-- two directions.
--
-- Deliberately NOT a demon lord. It is a big grunt with a title, because slot 1 is the line's front
-- door and the memorable thing on that board is meant to be the human standing next to it
-- (character_forsworn_knight), not this.
return {
    name = "The Breachward",
    archetype = "holdGround",
    sprite = "assets/chars/demon_grunt.png",
    stats = {
        health = 120, mana = 0, stamina = 50,
        staminaRegen = 2,
        damage = 16, magicDamage = 0,
        defense = 12, magicDefense = 6,
        movement = 0,
        speed = 2,
    },
}
