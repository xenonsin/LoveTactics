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
    magnitude = 30, -- percent off a mana cost while a foe is adjacent
    cheaperInMelee = true,
    strikesRefundMana = true,
}
