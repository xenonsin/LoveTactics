-- A greatsword, so it winds up (docs/weapons.md). Its extra is the SCHOOL: the blow lands `magical`, so
-- the heaviest hit in the game is routed through Magic Damage and turned by Magic Defense -- and armour,
-- which is the only thing a greatsword has ever really had to beat, gets no say in it at all.
--
-- Quest-only: `class` with no `price`.
--
-- The precedent is data/items/weapon/weapon_crescent_blade.lua, which does the same thing to a sword. The
-- reason it is worth doing twice is that the two families are stopped by different problems: a sword's
-- answer to plate is that it also parries, and a greatsword has no answer at all -- its whole design is
-- one enormous number aimed at the one stat the enemy stacks highest. This is the greatsword that stops
-- playing that game.
--
-- What it gives up is everything a caster gives up. A Silence, a status_magic_denied, or a
-- status_magical_barrier all bite on it exactly as they bite on a wand, which no other greatsword in the
-- game has ever had to think about -- and the wind-up means the enemy gets a turn to apply one after
-- seeing the raise. Its cost is still stamina, so it is not gagged by Silence; only what it DEALS is
-- sorcery, which is the narrow reading and the fair one.
return {
    name = "The Whitening",
    description = "Winds up, then falls on one tile for magical damage -- turned by Magic Defense, and untouched by armour.",
    flavor = "The smiths who made it were asked for something that could get through the Bastion's plate. Nobody specified through.",
    sprite = "assets/items/whitening.png",
    type = "weapon",
    -- `magical` in place of the family's usual physical: this is the deviation, and it is the weapon.
    tags = { "greatsword", "slash", "magical", "melee" },
    hands = 2,
    class = "fighter",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 7,
        channel = 2,
        -- Stamina, not mana. A fighter is who swings this, and a greatsword whose price was mana would be
        -- unusable by the class whose shelf it sits on -- what is magical here is the wound, not the work.
        cost = { stat = "stamina", amount = 16 },
        -- Under the iron greatsword's, because it is measured against Magic Defense, which almost nobody
        -- in plate has bought any of. The number is smaller and the number that ARRIVES is larger.
        damage = { 20, 22, 24, 26, 28, 30, 33, 35, 37, 39, 42 },
        effect = function(fx)
            if fx.target then fx.damage(fx.target) end -- tags default to the item's, so the hit is magical
        end,
    },
}
