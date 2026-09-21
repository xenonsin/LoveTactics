-- Beast: wolves, boars, bears, hawks, stags, and the things in the fen with too many legs.
--
-- COARSE ON PURPOSE, and this is the file to read before refining any of them. A wolf's race is "wolf",
-- which is a tautology; a bandit's race is "human", which is information. The axis answers a question
-- only bodied people have, so the creature kinds take a race named after their kind and carry nothing
-- else -- which is exactly what they carried when `kind` was authored on each blueprint.
--
-- A FINER RACE IS A REFINEMENT, NEVER A MIGRATION. `race = "wolf"` with `kind = "beast"` slots in
-- beside this one and every rule downstream keeps reading the kind, so a pack that wants its own hide
-- or its own tag costs one file and touches nothing. That is the whole reason kind rolls up from race
-- rather than being replaced by it.
--
-- No innate `resist` here, deliberately: the creature hides are authored per BODY (docs/bestiary.md's
-- redistribution pass measured them one animal at a time, and a bear and a hawk do not share a hide).
return {
    name = "Beast",
    description = "Things that hunt without being taught to. A wolf is what a Beastmaster has.",
    kind = "beast",
    playable = false,
}
