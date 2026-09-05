-- Encounter blueprint. THE TURNING FLOOR: a stretch that puts the company down somewhere it does not
-- recognise, and takes the map of it with them.
--
-- A SPINNER DOES NOT TRANSLATE, and this is what it became instead. In Wizardry you are looking out of
-- your own eyes at a corridor, so a floor that silently rotates you ninety degrees makes every note you
-- have written wrong and you do not find out for four turns. There is nothing to rotate here: the board
-- is drawn from above and north is on the screen, so a rotation would be a graphical trick the player
-- sees through immediately.
--
-- What a spinner actually costs you is your PLACE -- the certainty of where you are on the map you made
-- -- so that is what this takes. It re-fogs the ground around the company: the tiles you had walked go
-- back under, and the map has a hole in it exactly where you are standing. Everything you learned about
-- the rest of the floor is still yours, which is right; what is gone is your bearings.
--
-- Deliberately not a teleport. The Translation (encounter_translation) is the stop that MOVES you, and
-- two stops that both move you would be one stop with two names. This one leaves you where you stand and
-- takes the knowledge instead, which is the half of a spinner that survived the translation.
--
-- `weight = 0`: authored-only. See encounter_dark.lua.
return {
    name = "The Turning Floor",
    kind = "spinner",
    weight = 0,
    minDay = 1,
}
