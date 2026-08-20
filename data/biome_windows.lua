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
-- `. biome-report` will show castle days carrying more work than the rest. The eighteen have since
-- been RE-CUT rather than added to: the middle season gave four of its days back to the last week, on
-- the row itself, because four house lines end in the capital and none of them could reach it.
-- WHY THE FIRST FORTNIGHT IS WIDE. Measured, not guessed: `. biome-report` prints the live pool per
-- day, and on day 1 it is ONE -- the debut, which every gate in models/quest.lua conspires to make the
-- only thing on the board. A window that shuts the debut's ground is not pressure, it is a campaign
-- that cannot start, and the first draft of this table did exactly that (desert opened on day 10 and
-- the walk reported days 1-9 blocked under both play policies). The pool reaches six or seven by day
-- five, and that is the earliest a choice of destination can cost anything. So the grounds tighten as
-- the board widens rather than on a shape picked for its own sake.
return {
    -- id            windows, inclusive day ranges     open days
    -- THREE WINDOWS AND STILL EIGHTEEN DAYS. The third one is not extra capital, it is the middle
    -- season's own days moved to the end of the campaign, because that is where the capital is needed:
    -- four of the eight house lines FINISH here (arcanum, cathedral, undercroft, and the alchemist's
    -- last approach), and a table that shut the castle on day 31 shut it nine days before those endings
    -- could be reached. `. biome-report` said so directly -- the breadth walk ended with the True Ledger
    -- and the Next Unequalled live, castle-bound, and out of reach on every remaining morning, which is
    -- a blocked day whatever else is open. Their fiction cannot be widened out of it either: the ledger
    -- room is IN the Bank and the shortlist is read in the Arcanum's own halls.
    castle     = { { 1, 9 },   { 23, 27 }, { 34, 37 } }, -- 18
    forest     = { { 1, 16 },  { 30, 37 } }, --          24
    -- THE OTHER GROUND WITH THREE WINDOWS, and its third one is a hole being closed rather than a shape
    -- being drawn. The tundra used to shut for good on day 31, and `. biome-report`'s committed walk ran
    -- into the consequence the moment the Colosseum's re-homing shifted its route: on day 39 it held
    -- eight live quests and five of them were tundra, with nothing reachable anywhere. The last three
    -- days were three grounds wide while a third of the board's remaining work sat on a fourth.
    tundra     = { { 1, 7 },   { 17, 31 }, { 38, 40 } }, -- 25
    swamp      = { { 8, 22 },  { 32, 40 } }, --          24
    -- The sand is open on the first morning because the debut stands on it. See above.
    desert     = { { 1, 12 },  { 30, 38 } }, --          21
    volcanic   = { { 13, 29 }, { 36, 40 } }, --          22

    -- THE BOWL, and the one row that is a schedule in the fiction as well as in the table: a colosseum
    -- is not a country that becomes unreachable, it is a venue that is either running a card or dark.
    -- Open on the first morning because the debut is fought on it (quest_colosseum_slot_01), dark
    -- through the middle season while the house re-cards, and open again for the run at the patron that
    -- the line ends on. Shut over the last six days on purpose: by then the Gate is what the calendar is
    -- for, and a house still printing cards while the world ends is a house nobody believes in.
    colosseum  = { { 1, 11 },  { 22, 34 } }, --          24

    -- The Gate's own ground, and the only biome that is not a destination on the board. It opens for
    -- the last three days because the finale stands on it -- and the finale does not consult this
    -- table anyway (models/biome_window.lua's exemption), so this row is what the WORLD looks like as
    -- he arrives rather than a gate on anything.
    underworld = { { 38, 40 } }, --                       3
}
