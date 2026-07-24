-- Quarry's Due: the standing rule of the Poacher's charm of the same name. Anything caught in a trap
-- the bearer set is Marked.
--
-- A flag (Trait.flag) read by Trap.trigger, keyed off `trap.placer` rather than off the trap's SIDE --
-- which is why the placer field had to exist at all. Two hunters standing in the same line do not share
-- each other's charms, and a rule that fired on faction would have marked for whichever of them
-- happened to be holding this.
--
-- It is the wire between the two halves of the discipline. Traps were already on the Lodge's shelf and
-- executes were already on the Undercroft's, and nothing connected them: a Poacher was two shelves in
-- one grid rather than one idea. Now the snare is the setup and the Mark is the receipt.
--
-- Fired AFTER the trap's own effect, so a snare that Roots leaves its victim Rooted and Marked rather
-- than the two statuses racing each other -- which matters, because The Long Wait reads either one.
return {
    name = "Quarry's Due",
    marksTrapped = true,
}
