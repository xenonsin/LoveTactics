-- A DRAGON EGG: the kobold fights' signature object (reviewed 2026-09-24/25, "The Kobolds of Greed";
-- round 2: "Don't use gold, think of something else" -- it broods, it is not fed).
--
-- AN OBJECT THAT STANDS OUTSIDE THE TURN ORDER from the moment it is dealt (`timeless`), carrying two
-- rules in its grid:
--   * Dragonblood (trait_dragonkin): it is a DRAGON to a kobold. Kobolds within 3 of it fight under the
--     Dragon's Eye; a blow it survives drives the ones who see it to Fervor; smashing it leaves them Forsaken.
--   * The Clutch (trait_clutch): an ally that ends its turn beside it broods it, and at three it hatches a
--     Wyrmling on its tile.
--
-- LOW HEALTH ON PURPOSE, so a good blow smashes it outright -- a blow it survives rallies the line, and a
-- company that chips it has made the worst of both. It counts on the enemy's side, so a kill-all is not won
-- while an egg is standing: it has to be smashed, or it hatches and the Wyrmling has to be killed.
--
-- The company's own Dragon Egg (ability_dragon_egg) lays this same body on the company's side.
return {
    name = "Dragon Egg",
    race = "object",
    tier = 0,
    timeless = true,
    -- IT DOES NOT GROW WITH THE FIGHT. Measured on the road-fight harness at depth, a levelled egg shrugged a
    -- 94-point arrow, and "smash it in one blow" -- the whole of the egg's counterplay -- stopped being a
    -- thing a company could do. An egg is an egg on every floor.
    scaling = false,
    sprite = "assets/chars/dragon_egg.png",
    stats = {
        health = 16, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0,
        defense = 3, magicDefense = 3,
        movement = 0, -- it does not move
        speed = 0,    -- it takes no turns; it hears everyone else's
        skill = 0, luck = 0,
    },
    startingItems = { "utility_dragonblood", "utility_the_clutch" },
}
