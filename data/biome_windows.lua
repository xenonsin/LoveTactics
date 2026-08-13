-- THE SEASON TABLE: which ground is reachable on which of the forty days.
--
-- The calendar made the campaign a choice of WHAT to do with a day (models/calendar.lua). This makes
-- it a choice of WHERE, which is the half that was missing: with ninety-two quests all permanently on
-- offer, "which house do I advance" was a preference, never a deadline. A window is a deadline. The
-- swamp shuts on day twenty-one and the Alchemist's leg that sits in it goes with it until day
-- thirty-two, so a player who wants that leg has to spend a day on it now, against everything else
-- they wanted to spend the day on.
--
-- AUTHORED, FIXED, AND THE SAME EVERY CAMPAIGN. Not rolled per run. A schedule the player can learn
-- is a schedule they can plan against, and planning against it is the whole point -- a rolled table
-- would make each run's pressure arbitrary rather than solvable, and would turn a bad opening into
-- something that happened TO the player rather than something they misjudged.
--
-- THE ONE INVARIANT, pinned by tests/biome_window_spec.lua: AT LEAST THREE BIOMES ARE OPEN EVERY DAY,
-- all forty of them. Below three the board stops being a choice of destination and becomes a corridor,
-- and at one it is worse than no windows at all. Four is the ceiling in practice, not by rule.
--
-- Days are INCLUSIVE at both ends and one-based, matching Calendar.day: `{ 8, 20 }` is open on the
-- morning of day 8 and shut on the morning of day 21. A biome may hold several windows; they are read
-- in order and must not overlap (the spec checks).
--
-- WHY CASTLE IS THE NARROWEST. It is open eighteen days, fewer than any other ground, and that is
-- deliberate rather than an oversight: thirty-five of the ninety-two quests were authored in the
-- castle, and a schedule wide enough to carry all of them would have propped up the imbalance instead
-- of exposing it. The window is set where castle SHOULD sit -- about fifteen quests, level with its
-- neighbours -- and the re-authoring pass closes the gap from the other side. Until it does,
-- `. biome-report` will show castle days carrying more work than the rest.
-- WHY THE FIRST FORTNIGHT IS WIDE. Measured, not guessed: `. biome-report` prints the live pool per
-- day, and on day 1 it is ONE -- the debut, which every gate in models/quest.lua conspires to make the
-- only thing on the board. A window that shuts the debut's ground is not pressure, it is a campaign
-- that cannot start, and the first draft of this table did exactly that (desert opened on day 10 and
-- the walk reported days 1-9 blocked under both play policies). The pool reaches six or seven by day
-- five, and that is the earliest a choice of destination can cost anything. So the grounds tighten as
-- the board widens rather than on a shape picked for its own sake.
return {
    -- id            windows, inclusive day ranges     open days
    castle     = { { 1, 9 },   { 23, 31 } }, --          18
    forest     = { { 1, 16 },  { 30, 37 } }, --          24
    tundra     = { { 1, 7 },   { 17, 31 } }, --          22
    swamp      = { { 8, 22 },  { 32, 40 } }, --          24
    -- The sand is open on the first morning because the debut stands on it. See above.
    desert     = { { 1, 12 },  { 30, 38 } }, --          21
    volcanic   = { { 13, 29 }, { 36, 40 } }, --          22

    -- The Gate's own ground, and the only biome that is not a destination on the board. It opens for
    -- the last three days because the finale stands on it -- and the finale does not consult this
    -- table anyway (models/biome_window.lua's exemption), so this row is what the WORLD looks like as
    -- he arrives rather than a gate on anything.
    underworld = { { 38, 40 } }, --                       3
}
