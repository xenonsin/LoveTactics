-- Encounter blueprint. SCAVENGERS: the outfit that got to your pile before you did.
--
-- The guard on a big dropped pack (models/descent.lua's Descent.packGuard). You are not the only
-- company down here, word travels, and four bodies' worth of kit lying unattended on floor twelve is
-- the best day somebody else has had all season. They are wearing it when you come back.
--
-- `kind = "pack"`: the marker keeps its own colour and its own mark (ui/overworld_map.lua's
-- MarkerIcon.pack) so a player can tell their own loss from an ordinary fight from across the board,
-- and states/game.lua routes it into the arena beside combat and elite.
--
-- NO COMPOSITION HERE, and that is the one thing about this file worth explaining. The cast is drawn
-- ONCE, when the company falls, and stored on the drop as a list of ids -- so the fight is the same
-- fight across a save, a reload and a second attempt at it. A composition function on the blueprint
-- would re-draw the company every time the floor was re-entered, and a fight that is four bodies
-- before the save and six after it is not one the player can plan against. The list comes off the cell
-- (models/encounter_battle.lua reads `enc.composition` first for exactly this).
--
-- `weight = 0`: authored-only. Nothing rolls this onto a board -- it exists where a pile is and nowhere
-- else, and it must never turn up as ordinary traffic beside A Rival Company, which is the same draw
-- and is what the road is made of.
return {
    name = "Scavengers",
    kind = "pack",
    weight = 0,
    minDay = 1,
    description = "Somebody found what you left. They have had time to sort it, try it on and decide " ..
        "which of them carries what, and they are not going to hand it back.",
}
