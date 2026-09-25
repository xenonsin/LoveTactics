-- From Below: Sigurd's stroke, from a pit on the wyrm's path. Carried by Gram (data/items/weapon/weapon_gram.lua).
--
-- A FLAG, read by Combat.forcesCrit: on the bearer's own turn, before it has moved, a blow on a foe that
-- MOVED on its last turn and now stands adjacent is a critical. "Came to you" is read off the target's
-- own turn bookmark (turnStartX/Y, which Combat.startTurn lays and leaves in place until that unit's next
-- turn), so nothing new has to be remembered. Holding your ground is the price; a Mithril Shirt still
-- refuses the critical, as it refuses every forced one.
return {
    name = "From Below",
    description = "If you have not moved this turn, your strikes on a foe that came to you are criticals.",
    critOnArrival = true,
}
