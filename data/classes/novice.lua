-- Novice -- the STARTING class, and the one class with nothing above it that is not a root.
--
-- FFT's Squire. The avatar walks out of the village standing in this and nothing else; every root is
-- unlocked FROM it (Class.canUnlock: Novice 1, the root's own deed, and a Charter Seal). So it sits
-- below the seven rather than beside them, which is what `starter = true` says: no house shelves it,
-- no counter sells it, no exemplar posts it, and no requirement gates it -- every body holds it.
--
-- It is PLAYABLE -- a body can stand in it and climb it like any other class -- and it is the one class
-- that buys no stat boost while selected (Class.boostOf), because a boost is what a class you EARNED
-- pays and nobody earned this one. Companions keep their authored classes and never start here.
return {
    name    = "Novice",
    description = "Trained in nothing in particular, and so ready for anything. Grows a little in every "
        .. "stat, and is where every one of the seven trades is first unlocked.",
    starter = true, -- below the roots: no shelf, no house, no gate, no boost (models/class.lua)
}
