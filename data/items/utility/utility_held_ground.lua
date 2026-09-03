-- Held Ground: the knight's reading of the Overwatch stance. The Bastion does not sell a better shot,
-- it sells a worse approach -- the tiles beside a body standing on this are heavy to walk into.
--
-- WHAT IT IS. This is the game's zone of control, and it arrives as an ITEM rather than as a rule every
-- body obeys, which is a decision worth the paragraph (see docs/classes.md, under the knight):
--
--   * Fire Emblem and Those Who Rule make it universal, and it is load-bearing for them because their
--     maps are wide enough that a line genuinely cannot cover its own flanks. Ours is 8x8 with four
--     bodies a side (Arena.COLS, Combat.MAX_FIELD). Four bodies at x = 2, 4, 6, 8 already leave no gap
--     wider than a tile -- so the problem a universal zone SOLVES barely exists here, while the harm it
--     does is exact: four projectors a side would control half the board and lock the fight on turn two.
--   * So it is bought, not granted. One or two of these on a field is a shape; sixteen is a stalemate.
--
-- IT IS A COST, NOT A WALL. A watched tile is dear to enter, not forbidden (Combat.watchTax, spent
-- through the one place a tile is priced -- Combat's stepTerrainCost). That degrades where a hard stop
-- cannot: a fast body may still shove through by spending its whole move doing it, which is a decision,
-- where a hard stop is only ever a "no". It also means the counterplay was already in the game and
-- needed nothing written for it -- a flier never reads the ground at all, and Hasted discounts the
-- whole walk (Status.costMultiplier), so the two obvious answers already answer.
--
-- AND THE TAX IS INITIATIVE. `moveCost` doubles as the time a move bills, so wading past this does not
-- merely shorten the walk, it puts the walker further down the timeline. That is the real teeth, and it
-- is why the number is 2 and not 4: on a board this size, one point is the difference between "the
-- ground beside a sentry is heavy" and "I cannot move".
--
-- WHY IT RIDES ON OVERWATCH rather than being a passive aura. The stance already means *I am holding
-- this position and watching it* -- it already costs a whole turn to enter, and it already shoots
-- whoever walks into range. Slowing the ground beside it was the half that was missing, and the two
-- halves compound without being wired together: dear ground means more steps spent in the firing line,
-- and more steps in the firing line means more shots. Nothing else in this catalog does that.
--
-- ZONE 2 AGAINST THE SENTRIES' 1. The hunter's Overwatch Scope and the Stillhunter watch a wide band
-- and tax it lightly; this watches one square of road and makes it a bog. Same stance, opposite
-- emphasis -- which is the distinction between a sentry and a wall said in one number.
--
-- The shot itself is deliberately feeble by comparison: Overwatch fires the bearer's DEFAULT weapon
-- (Combat.triggerOverwatch), and a knight's is a sword, so this stance's reach is one tile. It is not
-- a worse Scope. It is a different thing wearing the same stance.
local Curve = require("models.curve")

return {
    name = "Held Ground",
    description = "Replaces Wait with Overwatch, and the ground beside you costs 2 more to enter.",
    flavor = "The gate did not hold because the man in it was unkillable. It held because going round took all afternoon.",
    sprite = "assets/items/held_ground.png",
    type = "utility",
    tags = { "charm" },
    class = "bulwark", -- deeper cut of the shelf: buyable only once the bulwark gate is cleared
    price = 410,
    unlockQuests = 4,
    -- `zone` is the tax; `stamina` the price of each answering shot; `speed` the turn it costs to set.
    -- Cheaper per shot than the Scope's 6 because a knight's reach is one tile and it will rarely get
    -- to fire more than once -- what this bearer is being paid for is the ground, not the volley.
    waitBehavior = { kind = "overwatch", speed = 12, stamina = 4, zone = 2 },
    -- A token of the drill, so the cell is not dead in a fight the bearer never gets to hold anything
    -- in. Defense, matching the Rooted Stance beside it on the same shelf: this is a way of standing.
    bonus = { defense = Curve.ramp(1, 11) },
}
