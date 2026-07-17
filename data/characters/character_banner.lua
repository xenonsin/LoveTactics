-- A planted banner: not a fighter but a standing object, reached only through a banner summon ability
-- (data/items/ability/ability_rally_banner.lua and its siblings). It never moves and never strikes, and
-- it takes no turns at all -- summoned control-"none" AND `timeless`, so it stands outside the
-- initiative timeline entirely and never occupies a slot in the turn order (Combat.inTimeline).
--
-- It does nothing whatsoever. The rally is the GROUND it holds open: planting a banner lays a 3x3 zone
-- (data/hazards/hazard_rally.lua and its siblings) that OWNS its effect, and this body's only job is to
-- be the thing that keeps that zone alive and the thing an enemy can cut down to end it. Kill it and
-- Hazard.dropOwnedBy takes the square with it; until then it stands.
--
-- It has real (if modest) health so it can be cut down -- knock the standard over to lift the buff --
-- and no mana or attack of its own. See data/characters/fire_elemental.lua for the conjured-creature
-- blueprint shape.
return {
    name = "Banner",
    sprite = "assets/chars/banner.png",
    stats = {
        health = 45, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0,
        defense = 5, magicDefense = 5,
        movement = 0, -- planted: it never moves
        speed = 0,    -- it takes no turns; the aura pulses on the clock, so speed buys it nothing
    },
    startingItems = {},
}
