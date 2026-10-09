-- LETHE HAZE: the Lethe-Drinker's rule (data/items/utility/utility_lethe_haze.lua). Approved 2026-10-09 ("The
-- Crown's Bestiary", slice E): "It carries the river with it. Any of your bodies within 2 tiles of it can't use
-- the same ability two turns running. It does nothing else to you directly."
--
-- A flag, asked at use by Combat.itemBlockReason through models/lethe.lua, so the slot greys, the press is
-- refused and the planner drops it in one place. Nothing it does is a reaction, so a Stun does not lift it.
return {
    name = "Lethe Haze",
    description = "Foes within 2 can't use the same ability two turns running.",
    letheHaze = true,
    radius = 2,
}
