-- A lesser demon: the antagonist the prologue introduces, and the fodder of the village attack
-- (states/prologue.lua). Deliberately weak -- this is the first fight the player ever sees, and its
-- job is to teach movement and a strike, not to threaten. The Demon Lord it serves is named in the
-- scene, not met (see docs/story.md).
return {
    name = "Demon Grunt",
    sprite = "assets/chars/demon_grunt.png",
    stats = {
        health = 40, mana = 0, stamina = 40,
        damage = 8, magicDamage = 0,
        defense = 4, magicDefense = 2,
        movement = 3,
        speed = 2,
    },
    startingItems = { "weapon_iron_sword" },
}
