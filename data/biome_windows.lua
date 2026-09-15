-- THE SEASON TABLE: which ground is reachable on which day.
--
-- The board answers "what work is posted" (models/bounty.lua). This answers "and which of it can be
-- reached this morning", which is the half that makes a board a choice of WHERE. Without it every
-- house's opener is permanently on offer and picking one is a preference rather than a decision.
--
-- AUTHORED, FIXED, AND THE SAME EVERY CAMPAIGN. Not rolled per run. A schedule the player can learn is a
-- schedule they can plan against, and planning against it is the whole point -- a rolled table would
-- make each run's pressure arbitrary rather than solvable, and would turn a bad opening into something
-- that happened TO the player rather than something they misjudged.
--
-- IT REPEATS RATHER THAN RUNNING OUT. It was written for a forty-day campaign with a deadline at the
-- end; the deadline is retired and a day has no ceiling now, so forty days is a SEASON that comes round
-- again (models/biome_window.lua's SEASON and seasonDay).
--
-- WHAT IT GATES, AND WHAT IT DELIBERATELY DOES NOT. It decides which houses are posting their STANDING
-- offers. A posting the company is already holding is always on the board whatever the season says --
-- a bounty in hand was paid for, and a schedule that could make it unspendable would be taking back a
-- bet already placed (models/bounty.lua's offered).
--
-- ---------------------------------------------------------------------------
-- THIS TABLE WAS RE-CUT, and what it was cut for is worth recording because the old shape looked
-- deliberate and had stopped being so.
-- ---------------------------------------------------------------------------
--
-- The previous schedule was authored against NINETY-TWO quests whose grounds were distributed very
-- unevenly -- thirty-five of them in the castle -- and the windows were sized to expose that imbalance
-- rather than prop it up. That was the right call for that content. The content is gone: what the board
-- carries now is seven house openers, one per ground.
--
-- The old table read as follows under the new load, and both numbers are the same defect:
--
--   * `underworld` was open THREE days out of forty, so the Undercroft could post on three mornings a
--     season. It was a rare late-game ground when the quests decided where work happened; it is one
--     house's front door now.
--   * Three of the seven openers sat in the swamp, so the count that actually matters -- how many
--     HOUSES are posting -- fell to TWO on day 28, while the ground count looked fine at three. The
--     invariant was guarding the wrong noun. tests/bounty_spec.lua counts houses now.
--
-- SO THE CUT IS COMPUTED RATHER THAN HAND-TYPED. Each ground takes one twenty-four day span -- sixty
-- per cent of the season, shut often enough to press and open often enough to plan -- staggered evenly
-- around the season and wrapped. Measured over the result: never fewer than THREE houses posting (the
-- floor below which the board stops being a choice and becomes a corridor) and never fewer than FOUR
-- grounds open. Both are pinned, in tests/bounty_spec.lua and tests/biome_window_spec.lua respectively.
--
-- Even spans rather than hand-tuned ones is a deliberate first pass: there is no longer a content
-- imbalance for the schedule to argue with, so the honest starting point is the flat one, and any
-- future unevenness should be put here on purpose and said out loud.
--
-- `volcanic` carries no house opener -- the Colosseum posts on its own sand -- and keeps a span anyway,
-- because it is a real ground that derived rungs and arenas are fought on and a ground open zero days
-- is one nobody meant to ship.
--
-- Days are INCLUSIVE at both ends and one-based, matching Calendar.day: `{ 8, 20 }` is open on the
-- morning of day 8 and shut on the morning of day 21. A ground may hold several windows; they are read
-- in order and must not overlap (the spec checks).
return {
    tundra     = { { 1, 24 } },                  -- the Bastion
    colosseum  = { { 6, 29 } },                  -- the Colosseum
    forest     = { { 11, 34 } },                 -- the Cathedral
    swamp      = { { 16, 39 } },                 -- the Hunter's Lodge
    underworld = { { 1, 4 },  { 21, 40 } },      -- the Undercroft
    desert     = { { 1, 9 },  { 26, 40 } },      -- the Crucible
    castle     = { { 1, 14 }, { 31, 40 } },      -- the Arcanum
    volcanic   = { { 1, 19 }, { 36, 40 } },      -- no opener; arenas and derived rungs
}
