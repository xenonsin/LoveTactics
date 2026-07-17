-- A pig. Not a combatant -- a SHAPE, worn by whoever a Polymorph lands on (data/status/polymorph.lua)
-- and never summoned, recruited, or fought as itself.
--
-- The defining fact is what isn't here: no `startingItems` and `unarmed = false`, which between them
-- mean the body has no ability of any kind (see Character.DEFAULT_UNARMED). Combat.defaultWeapon
-- returns nil, the enemy AI finds nothing to swing and falls through to "walk toward the enemy", and a
-- player-controlled pig can move and end its turn and do precisely nothing else. That is the whole
-- spell: polymorph does not damage you, slow you, or shove you down the order -- it takes away your
-- VERBS, and leaves you the run of the board to think about it.
--
-- The health/mana/stamina below are placeholders that are never used. A transform carries the original
-- body's pools across verbatim (see models/transform.lua) -- a pigged champion has a champion's health
-- bar -- because a shape that brought its own would make polymorph an execute rather than control.
--
-- The flat stats DO apply, and they are the cost of the shape: no defense worth the name, so a pig is
-- softer than whatever it used to be. Being turned into livestock is not merely inconvenient; it is
-- dangerous. Movement stays generous -- it can run, and running is the only thing left to it.
return {
    name = "Pig",
    sprite = "assets/chars/pig.png",
    stats = {
        health = 1, mana = 0, stamina = 0, -- placeholders: the original's pools are carried across
        staminaRegen = 0,
        damage = 0, magicDamage = 0,
        defense = 1, magicDefense = 1,
        movement = 4, -- it can run, and that is all it can do
        speed = 2,
    },
    startingItems = {},
    unarmed = false, -- no fists, no fangs, no actions: the point of the spell
}
