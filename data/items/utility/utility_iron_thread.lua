-- IRON THREAD: what the Sewn-Eyed Penitents drop (data/characters/character_sewn_eyed_penitent.lua; "Envy's
-- Bestiary", 2026-10-03, slice C). The wire that sews their eyes: you cannot be Blinded, and Invisible foes within
-- 2 of you are Limned, so they can be targeted (trait_iron_thread -- the Skull-Lantern's light, at its reach of 2).
--
-- The page said "you can target Unseen foes within 2". Limned is the game's one way to make a hidden body
-- targetable, and it lights the body for the whole company, so the text names it.
--
-- An Inquisitor's: finding what hides is that shelf's. An unstocked trophy on the seat's rung.
return {
    name = "Iron Thread",
    description = "You cannot be Blinded, and Invisible foes within 2 of you are Limned.",
    flavor = "It was put there so you would stop looking. It works the other way as well.",
    sprite = "assets/items/utility_iron_thread.png",
    type = "utility",
    tags = { "charm" },
    class = "inquisitor",
    unlockLevel = 12,
    unstocked = true,
    statusImmunity = { "status_blind" },
    traits = { "trait_iron_thread" },
}
