-- Breaker's Wedge: the standing rule of the Vanguard's charm of the same name. Every shove its bearer
-- throws also Sunders the body it moved.
--
-- A FLAG rather than a hook (Trait.flag, consulted by Combat.shoveRiders): the shove already knows who
-- was thrown and how far, so the charm only has to answer yes.
--
-- What makes it the Vanguard's keystone rather than a convenience is the arithmetic of the catalog:
-- nineteen items cause knockback -- the whole mace family does it innately (docs/weapons.md) -- and
-- barely a handful apply Sundered. This charm converts the first number into the second. A Vanguard
-- holding it turns any shove in the game, including ones authored years before this file, into an
-- armour-breach; that is a discipline mechanic rather than an item's effect, which is exactly what a
-- signature is supposed to be.
return {
    name = "Breaker's Wedge",
    sundersOnShove = true,
}
