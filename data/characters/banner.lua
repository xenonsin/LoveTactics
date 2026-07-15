-- A planted banner: not a fighter but a standing object, reached only through a banner summon ability
-- (data/items/ability/ability_rally_banner.lua and its siblings). It never moves and never strikes --
-- summoned control-"none", it holds its ground and passes every turn -- but each of those turns fires
-- its Banner Aura (data/status/banner_aura.lua), sweeping the 3x3 around it and granting nearby allies
-- the status it was raised to spread. Kill it and the rally ends; until then it stands.
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
        speed = 5,    -- how often it comes around to pulse its aura
    },
    startingItems = {},
}
