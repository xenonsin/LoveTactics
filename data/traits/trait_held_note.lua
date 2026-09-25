-- HELD NOTE's rule (the Lorelei's rock, and data/items/utility/utility_held_note.lua): once a battle, the
-- first thing that would break the bearer's sustained cast does not. `stacks` is the spent mark
-- (Combat.holdsTheNote sets it), and a body is rebuilt for every fight, so the once is per battle.
return {
    name = "Held Note",
    description = "The first time each battle your channel or song would break, it does not.",
    heldNote = true,
}
