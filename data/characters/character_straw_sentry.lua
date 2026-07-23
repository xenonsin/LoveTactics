-- A straw sentry: a jacket, a helm and a bundle of straw on a cross-frame, stood up in the mud where a
-- man would be. Not a fighter -- a standing object, reached only through the ability that plants it
-- (data/items/ability/ability_straw_sentry.lua). It never moves and never strikes, and like the banner
-- it takes no turns at all: summoned control-"none" AND `timeless`, so it stands outside the
-- initiative timeline entirely and never occupies a slot in the turn order (Combat.inTimeline).
--
-- It does nothing whatsoever, and that is the entire point of it. What it buys is ATTENTION: the
-- ability that plants it Taunts the enemies around it toward the dummy, and every turn one of them
-- spends hacking a bundle of straw apart is a turn nobody spends on the knight. Compare
-- data/characters/character_banner.lua, which is the same shape of object holding the opposite kind of
-- ground open -- a banner is a thing you defend, and this is a thing you are delighted to lose.
--
-- Its health is therefore the whole of its statline, and it is deliberately modest: a sentry that
-- soaked a full turn from three attackers would be a wall rather than a lie. It has no mana, no
-- stamina and no attack, and its defense is low -- straw does not turn a blade, it only occupies one.
return {
    name = "Straw Sentry",
    sprite = "assets/chars/straw_sentry.png",
    stats = {
        health = 24, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 0, -- planted: it never moves
        speed = 0,    -- it takes no turns
    },
    startingItems = {},
}
