-- GYEOM'S GRIMOIRE. She came into the rift alone to LEARN -- there are workings down here that exist
-- nowhere above it -- and she found one: a grimoire, with something sitting on it. She cannot take it
-- off alone and she has counted properly enough to know that rather than guess it. She asks for help,
-- STANDS IN THE FIGHT HERSELF (`allies` below), and joins when it is done.
--
-- THE SHAPE IS "HELP ME WITH THIS", NOT "FETCH THIS FOR ME", and every part of the objective says so:
-- one monster rather than a crew, her on the board rather than waiting on the step, and a `protect` on
-- her so the help has to actually be help. What she is really asking for is the rest of the descent --
-- the book is one working and the company is how she reaches every other one -- but the ask in front of
-- the player is small and concrete, which is what an opener should be.
--
-- RE-PREMISED 2026-09-16 FOR THE DISTANCE RUN. This was "The Sunken Sanctum": looters had reached a
-- flooded reading room the rift had copied out of the world above, and the Arcanum wanted its book
-- back. That belonged to the parked campaign -- a fixed errand in a fixed place, sponsored by a house --
-- and the mode it sits in now scores DEPTH, rebuilds the dungeon every descent, and has no copied place
-- for anybody to have looted. See data/conversations/arcanum/conversation_arcanum_errand_found.lua for
-- the full record of what the scenes stopped saying.
--
-- `sponsor` and `rewardGold` are left as they are: this is still structurally a house's opener and the
-- Arcanum still pays for it. What changed is that the WORK is hers rather than theirs -- she is not
-- running an errand for the college, she is stuck, and the house settles up afterwards.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "As Far As She Got",
    -- The work in one line, read as a spoken line rather than as a notice on a board: the city has no
    -- Quest Board any more, and the only code that reads this field is the companion posting scenes
    -- through `{posting}` (states/game.lua sets player.postingWork off it). Written to the premise the
    -- meeting scenes stand on: she came down here to learn, and something is sitting on the first thing
    -- she found worth learning.
    description = "There is a grimoire under that thing, and she cannot lift it off alone.",
    difficulty = "Normal",
    sponsor = "arcanum",
    -- The thanks for the job that OPENS this house. Its opener is seated on a descent floor unasked
    -- (models/errand.lua), so this scene is where the house first learns who ran it -- and the greeting
    -- waiting at its counter picks up from these lines.
    outro = "conversation_arcanum_slot_01_outro",
    rewardItems = { "weapon_iron_crook", "armor_gleaners_mantle" },
    rewardGold = 140,
    -- THE COMPANION JOINS HERE. This is the ask they make when you meet them on a floor
    -- (models/errand.lua), and clearing it is what brings them into the company -- the same
    -- route Saber has always arrived by. Quest.complete calls Player.recruit before the outro
    -- fires, so the "[X has joined your Party]" banner and their first words land in one beat.
    rewardCharacter = "character_gyeom",
    requiredPrestige = 3,
    map = {
        biome = "swamp",
        encounters = { min = 5, max = 8, always = { "encounter_elite" } },
        objective = {
            name = "The Thing on the Book",
            -- ONE BODY, AND IT IS THE WHOLE FIGHT. It replaces a champion and a scaling pack of
            -- bandits, because the ask is "a monster is sitting on the book" and a crew of people is a
            -- different sentence. Its reach is one tile and its swing is slow, so it is answered the way
            -- a big animal is answered -- see it coming and do not be there -- which is a good shape for
            -- the first real fight of the mode: positioning, not arithmetic.
            --
            -- A COFFER-CRAWLER WAS THE FIRST PICK AND THE SUITE REFUSED IT, twice over, which is worth
            -- recording because it is the same mistake anybody would make. Its header reads like this
            -- scene already written ("slow, heavy, and standing between you and whatever you actually
            -- wanted") -- but tests/balance_spec.lua measured it swinging 18 for 6 a hit, eleven hits to
            -- fell the reference body against a band of five to ten, and tests/descent_spec.lua rated the
            -- board at 250% of the company, which is Muster.canWalkOver -- the game would have OFFERED TO
            -- AUTO-RESOLVE Gyeom's recruit fight. A guardian that cannot threaten is not a guardian.
            --
            -- A LONG FIGHT IS ALSO WHAT SHE NEEDS. Gyeom stands in this one (see `allies`) and her Ledger
            -- pays out only after four actions (data/items/utility/utility_ledger.lua), so a heavy single
            -- target is the one fight where the player watches her Release land BEFORE being offered the
            -- body that threw it. A swarm that folds in two rounds introduces her as a mage who does
            -- nothing.
            --
            -- IT SWALLOWS A BODY WHOLE (weapon_grendlemaw_gullet, status_suspended) and that is safe
            -- beside the `protect` below rather than a trap: suspended carries no damage tick, just a
            -- duration and an initiative shove, so a swallowed Gyeom is ABSENT and not dying somewhere
            -- the player cannot reach her. The monster eating the mage you are keeping alive is the
            -- fight's best beat, and it resolves itself.
            composition = function() return { "character_grendlemaw" } end,
            -- SHE FIGHTS BESIDE YOU AND YOU DO NOT COMMAND HER. `allies` seats a non-party character on
            -- the party's side under AI control (models/arena.lua's bindAllies, control = "ai"), which
            -- is the honest shape for somebody who has asked for help rather than taken orders -- and it
            -- lets the player see exactly what they are being offered. Her own authored `ai` runs her:
            -- skirmish posture, break off under a third health, spend the Ledger when something is in
            -- range (data/characters/character_gyeom.lua), so she plays like herself.
            allies = { "character_gyeom" },
            -- ...AND KEEPING HER UP IS PART OF THE JOB, because "help me kill it" is not helped if she
            -- dies doing it. A composable LOSS condition (Combat.evaluate checks `protect` before the
            -- win type), so the fight is lost rather than the companion -- the errand stays on the floor
            -- and can be walked back to. Her retreat rule is what keeps this from being a babysitting
            -- problem; she takes herself out of trouble.
            protect = "character_gyeom",
            win = { type = "assassinate", target = "character_grendlemaw" },
        },
        keyCount = 2,
    },
}
