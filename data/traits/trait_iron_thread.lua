-- IRON THREAD: the Inquisitor's (data/items/utility/utility_iron_thread.lua; "Envy's Bestiary", 2026-10-03, slice
-- C, the Sewn-Eyed Penitents' drop). The wire that sews a penitent's eyes, carried: Invisible foes within 2 of the
-- bearer are Limned and can be targeted (`limnsNear`, Status.lanternLit -- the Skull-Lantern's light, at its
-- reach of 2). The immunity to Blind is on the item.
return {
    name = "Iron Thread",
    description = "Foes within 2 of you are Limned.",
    limnsNear = true,
}
