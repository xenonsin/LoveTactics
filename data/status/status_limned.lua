-- Limned: the bearer is lit, and no longer gets to say it isn't there. Status.untargetable answers
-- false for a limned unit whatever else it is wearing, so an invisible body standing in Witchlight can
-- be picked, shot, and cursed like anything else.
--
-- THE GAP IT FILLS. Invisibility, decoys and Stillshade all say "you may not aim at me", and nothing in
-- this game said otherwise. The answer was to wait it out, which is not counterplay, it is patience.
-- This is the answer: a consumable somebody gave up a slot for and a turn throwing.
--
-- Note what it does NOT do. The bearer keeps its Invisible status and everything else that status pays
-- it -- only the untargetability is overruled, because that is the only part of hiding the light has any
-- business arguing with. A rogue in Witchlight is a rogue who is still hidden and can still be shot,
-- and that distinction matters the moment it steps out of the light: the concealment is waiting for it,
-- unspent, exactly where it left it.
--
-- ZONE-BOUND. It declares no `lingers`, so the grant is stamped with the Witchlight's id as its source
-- (models/hazard.lua) and it ends the instant its bearer steps off the lit ground or the light burns
-- out. You are found while you stand in it, and not one beat longer -- which is what makes the flare a
-- piece of GROUND the thrower has to place well, rather than a debuff they landed.
return {
    name = "Limned",
    abbr = "Limn",
    description = "Limned: lit up, and targetable however well it is hidden.",
    color = { 0.98, 0.94, 0.72 }, -- badge tint (flare white-gold)
    duration = 8,                 -- the backstop; the light under it is what really holds this up
    debuff = true,                -- a Cure lifts it, at the price of the cure
    revealsBearer = true,
}
