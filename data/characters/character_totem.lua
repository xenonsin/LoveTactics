-- A Totem: a carved stake a Totemist plants to hold a patch of ground open. Like the Banner
-- (data/characters/character_banner.lua) it is a standing object, not a fighter -- summoned
-- control-"none" AND timeless, so it never moves, never strikes, and takes no turns. What ground it
-- holds depends on the item that raised it: a Carved Stake lays a warding zone, a Raise Totem a healing
-- one. Real (modest) health so an enemy can cut it down to lift the zone.
return {
    name = "Totem",
    sprite = "assets/chars/totem.png",
    stats = {
        health = 24, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0,
        defense = 4, magicDefense = 6,
        movement = 0, -- planted
        speed = 0,    -- takes no turns; the zone answers to the clock
    },
    startingItems = {},
}
