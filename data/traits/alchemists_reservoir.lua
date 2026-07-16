-- Alchemist's Reservoir: a caster who, finding a spell beyond their mana, simply opens a flask and
-- casts it anyway. The bottled cousin of Arcane Reservoir (data/traits/arcane_reservoir.lua) -- and
-- the comparison is the point of both:
--
--   * Arcane Reservoir breaks the game's "mana never regenerates" rule for one body. It is a TRICKLE,
--     it is free forever, and it rewards a long fight.
--   * This one breaks nothing. It rewards PACKING. It is a lump sum, it is finite, and it runs out --
--     what it sells is not mana, it is the right to spend your mana down to nothing and still have the
--     one cast that mattered.
--
-- Like Overchannel and Arcane Reservoir, the recovery loop reads this as a CAPABILITY rather than
-- dispatching a hook -- there is no "onSpend" trait event, so the cost path consults it directly
-- (Combat.canDrawOnPotion) and the def carries no hook of its own. Both halves of the price gate see
-- it: Combat.itemBlockReason stops greying out a spell the flask would cover, and Combat.spendCost
-- opens the flask on the way through.
--
-- It reaches for a draught only when the mana genuinely falls short, and only for a spell the flask
-- would actually cover -- so it never opens one it didn't need, and never opens one that wouldn't have
-- been enough. A caster carrying this AND Overchannel drinks first and bleeds second: stock is the
-- cheaper of the two prices, and a mage burning its own health with a full flask in the satchel would
-- read as a bug even when it wasn't one.
return {
    name = "Alchemist's Reservoir",
    description = "When a spell outruns your mana, you drink a mana draught to cast it anyway.",
}
