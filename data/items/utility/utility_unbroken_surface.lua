-- The King's FIRST rule, worn, and bounded to the one turn it is allowed to be worn for: the bearer
-- opens every battle proof against blades, points and blows.
--
-- The other half of what the fen taught (the Quicksilver Mantle is the adaptation; this is the
-- surface). Three opening boons rather than one, because "physical" is three independent claims in
-- this engine and a piece that turned aside a sword and not a bare fist would be a bug nobody could
-- see -- the same reason utility_amorphous_body names all four words on the body itself.
--
-- WHY AN OPENING BOON AND NOT A STANDING IMMUNITY. The obvious lift is `immune` on the item, exactly
-- as the King wears it. That is the one thing this must not be. A body the enemy cannot hurt with a
-- weapon is a puzzle when the ENEMY is wearing it -- the player answers with an element, and the
-- fight is about the answer. Pointed the other way there is no puzzle to solve, only an AI with no
-- move: `models/ai.lua` does not read damage-type immunity when it picks a target, so a company
-- wearing this would be fought by enemies swinging into a wall forever. The window is what turns a
-- wall back into a decision -- who walks in first, and what you spend the free turn on.
--
-- SIX TICKS, which is the Seal line's own number (data/status/status_immune_slash.lua and its two
-- kin, granted at duration 6 by ability_seal_slash). Deliberately not re-tuned here: this is three
-- of a shipped ward stacked on one opening, and a bespoke duration would be a second answer to a
-- question the Arcanum's shelf already answered. Roughly one turn.
--
-- It stacks with nothing and pays nothing after that turn -- no defense, no resist, no rule. What it
-- buys is the OPENING, which against a line of archers is most of a fight and against a caster is
-- nothing at all, and choosing which of those you are walking into is the whole of carrying it.
--
-- RIFT-ONLY (`unstocked`): it comes off the body and nowhere else. No counter deals one however many
-- the company carries out, and none will buy one back (Vendor.foundPrice). Still yours to move,
-- forge and break down -- it is simply not merchandise.
return {
    name = "The Unbroken Surface",
    description = "Open each battle proof against blades, points and blows.",
    flavor = "The Crucible has a standing offer for a whole one. Nobody has ever brought a whole one.",
    sprite = "assets/items/utility_unbroken_surface.png",
    type = "utility",
    tags = { "protective" },
    class = "alchemist",
    -- AUTHORED OVER THE TOOL, AND THIS IS THE ARGUMENT. `. drop-tier` grades this at 0.0 and wants
    -- tier 1, and it is not wrong by accident: models/grade.lua says outright that "an immunity that
    -- names tags is worth nothing at all unless the blow coming in carries one", so a piece whose
    -- ENTIRE payload is three tag-immunities grades at the floor by the grader's own stated design.
    -- That reading is right for pricing a ward nobody knows they will need and wrong for placing a
    -- boss's unique piece, which is a fact about where it is FOUND. Four, so the King's list pays one
    -- thing at each rank an elite band can reach it at (4-5 at day 14, 7-8 at the bottom).
    dropTier = 4,
    unstocked = true,
    -- A LIST, which `Curse.openingBoons` unwraps for the one reader that matters (states/battle.lua's
    -- setup). Three statuses because the engine keys immunity per tag, not per school.
    openingBoon = {
        { id = "status_immune_slash" },
        { id = "status_immune_pierce" },
        { id = "status_immune_impact" },
    },
}
