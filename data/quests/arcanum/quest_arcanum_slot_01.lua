-- GYEOM'S GRIMOIRE. She came into the rift alone to LEARN -- there are workings down here that exist
-- nowhere above it -- and she found one: a grimoire, with something sitting on it. She cannot take it
-- off alone and she has counted properly enough to know that rather than guess it. She asks for help,
-- STANDS IN THE FIGHT HERSELF (`allies` below), and joins when it is done.
--
-- RESTORED 2026-10-14. data/quests went in 92ff549d with every posting in it, and with them every way a
-- named companion could join; the deal (Descent.dealCompanion) and the payout (states/game.lua) were
-- left standing and seated nobody. This is the same ask with two things changed:
--
--   * THE THING ON THE BOOK IS A GIANT TOAD. The Grendlemaw it used to be is deleted, and Gyeom is
--     scripted onto floor one (Descent.SCRIPTED_COMPANION_FLOOR), which on a first descent is Gluttony's
--     wood -- so the body comes off that circle's own stock. It is the one animal in the wood that eats
--     you whole, which is the beat the Grendlemaw was picked for, and it is safe beside the `protect`
--     for the reason that one was: digestion never takes the last point (status_swallowed's onTick), so
--     a swallowed Gyeom is ABSENT, not dying where the company cannot reach her. Hitting the toad for a
--     quarter of its health spits her back out, which is the fight's lesson and the counter it teaches.
--   * NO GOODS. Its `rewardItems` were the Iron Crook and the Gleaner's Mantle, which are rift finds on
--     the mage ladder now (rungs 12 and 2) -- handing a rung-12 staff over on floor one would be a
--     shortcut past the ladder. The purse stays; the reward is her.
return {
    name = "As Far As She Got",
    -- Read aloud through `{posting}` by the companion scenes (states/game.lua sets player.postingWork off
    -- it), and by nothing else -- so it is a spoken line, not a notice on a board.
    description = "There is a grimoire under that thing, and she cannot lift it off alone.",
    difficulty = "Normal",
    sponsor = "arcanum",
    outro = "conversation_arcanum_slot_01_outro",
    rewardGold = 140,
    -- THE COMPANION JOINS HERE: the descent's errand payout calls Player.recruit on this field.
    rewardCharacter = "character_gyeom",
    -- READ ONLY BY models/balance.lua, which still measures a quest's bodies at a campaign standing:
    -- the standing at the first floor of the circle she is met in (Gluttony, floor one on the authored order),
    -- so a deep circle's stock is judged against the company that actually meets it.
    requiredPrestige = 1,
    map = {
        -- The ground of that circle. The descent picks its own ground off the floor, so this is the
        -- authored claim tests/biome_spec.lua validates, not what draws the board.
        biome = "forest",
        objective = {
            name = "The Thing on the Book",
            -- ONE BODY, AND IT IS THE WHOLE FIGHT. "Something is sitting on the book" is one sentence and
            -- one monster. A LONG fight is also what she needs: her Ledger pays out only after four actions
            -- (utility_ledger.lua), so a heavy single target is where the player watches her Release land
            -- before being offered the body that threw it.
            composition = function() return { "character_giant_toad" } end,
            -- SHE FIGHTS BESIDE YOU AND YOU DO NOT COMMAND HER (models/arena.lua's bindAllies, control =
            -- "ai"): somebody who has asked for help, not taken orders, run by her own authored `ai`.
            allies = { "character_gyeom" },
            -- ...and keeping her up is part of the job. A loss condition (Combat.evaluate checks it before
            -- the win type), so the fight is lost rather than the companion and the ask stays on the floor.
            protect = "character_gyeom",
            win = { type = "assassinate", target = "character_giant_toad" },
        },
    },
}
