-- Battle Casting: the standing rule of the Battlemage's charm. Workings thrown with a foe in your face
-- cost less, and weapon strikes hand a little mana back.
--
-- Two flags, one idea, read at two seams (Combat.spendCost and Combat.dealDamage): the battlemage is
-- cheapest exactly where a mage is most frightened, and its steel funds its sorcery.
--
-- That inversion is the discipline's whole argument. Every other caster in the game is built to be
-- somewhere else -- range, line of sight, a wall between you and the thing. This one is only worth what
-- it costs when something is already swinging at it, which is why it belongs on a fighter's grid rather
-- than on a robe.
--
-- The refund is small and physical-only. It is not an engine for infinite casting; it is the reason a
-- battlemage out of mana is one swing away from being back in the fight rather than a fighter with bad
-- armour.
return {
    name = "Battle Casting",
    description = "Reduces the mana cost of your spells while a foe is adjacent. On damage dealt with a weapon: restore mana.",
    -- Both figures are read through Trait.param, so the granting item may raise them and both seams in
    -- models/combat.lua spend what the item actually says. These are the floor a granter that names
    -- neither would run on; the Battle Casting charm authors both as curves and the bench climbs them,
    -- which is why the description quotes neither -- no single number is true across the forge, so the
    -- item's Spell Discount and Strike Refund rows carry them (docs/item-text.md).
    meleeDiscount = 30, -- percent off a mana cost while a foe is adjacent
    strikeRefund = 3,   -- mana handed back by a non-magical blow that lands
    cheaperInMelee = true,
    strikesRefundMana = true,
}
