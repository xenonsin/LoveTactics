-- THE SEED: one number that says what a playthrough is made of.
--
-- A save carries a seed, and everything that gets ROLLED in that save hangs off it -- the order of the
-- circles once the shuffle is open, the deal of houses across the floors, the guard standing over a
-- dropped pack, and the ground each floor is carved into. Two saves on the same seed walk the same rift.
--
-- WHY IT IS WORTH HAVING, since the mode already reproduced most of a floor from `run.seed`. Because
-- `run.seed` was a clock read (`os.time()`), and a clock read is a seed nobody can say. A bug report
-- that begins "floor four had no way down" is unanswerable without one; a player who wants to hand a
-- friend the run they just had has nothing to hand over; and a spec pinning a run is pinning something
-- live play can never reach. One number at the top of the save fixes all three at once, and costs a
-- field.
--
-- ONE CLOCK READ, AT THE TOP. Seed.roll is the only place in this file that asks what time it is, and
-- Player.new is the only caller -- so a game is random exactly once, when it begins, and deterministic
-- from there down. Everything below derives.
--
--   the save        `player.seed`, minted at Player.new (six digits, so it can be read off a screen)
--   a lap           Seed.lap -- the save's seed folded with `ngPlus`, so New Game+ is its own rift
--   a descent       Seed.run  -- the lap's seed folded with which run this is, counted on the player
--   a floor's board states/game.lua folds the run's seed with the depth
--
-- WHAT IT DOES NOT DECIDE is the order of the seven circles on a FIRST descent: that is authored
-- (models/descent.lua's Descent.INFERNO) and no seed moves it. The seed deals the shuffle that the
-- Crown falling opens up, and nothing before it.
--
-- Pure arithmetic, no love, no state. Headless.

local Seed = {}

-- SIX DIGITS, and the reason is that a seed a player cannot read back is not a seed. Everything here
-- lands in 0..999999 so it fits on a line, gets said out loud, and is typed in again without a mistake.
Seed.SPAN = 1000000

-- The modulus the mixing runs under: 2^31-1, a prime, and the largest that keeps every intermediate
-- product below 2^53 with the multipliers used here.
local MOD = 2147483647

-- WHY THIS IS HAND-ROLLED ARITHMETIC AND NOT A LIBRARY. This is Lua 5.1 (LOVE's interpreter): there are
-- no bit operators, no integers, and every number is a double. So the mixing is multiply-and-mod, and
-- the ONE rule it obeys is that no intermediate product may exceed 2^53 -- past that a double stops
-- being exact and the "hash" becomes a rounding artifact. 65599 is chosen for that: MOD * 65599 is
-- about 1.4e14, comfortably inside the exact range, so this answers identically on every machine.
--
-- The tail is not decoration. Everything above it is affine in the inputs, so mixing (base, 0) and
-- (base, 1) would come out one apart -- and two laps of the same save would read as consecutive
-- numbers, which is a seed that looks broken even when it is not. Swapping the halves and weighting the
-- low one breaks that: a difference of one at the input is a difference of two million at the output.
function Seed.mix(...)
    local h = 5381
    for i = 1, select("#", ...) do
        local v = tonumber((select(i, ...))) or 0
        h = (h * 65599 + math.floor(v) % MOD) % MOD
    end
    h = (h * 65599) % MOD
    h = ((h % 65536) * 32749 + math.floor(h / 65536)) % MOD
    return h % Seed.SPAN
end

-- A string folded into the same space, so a seed can be taken against something named rather than
-- numbered (a quest id, a ground). Byte-wise and order-sensitive; the same rule about staying inside
-- the exact range applies, which is why it mods every step rather than at the end.
function Seed.text(s)
    if type(s) ~= "string" then return 0 end
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % MOD
    end
    return Seed.mix(h)
end

-- MINT A FRESH ONE. The only clock read in the seed path, and Player.new is its only caller.
--
-- The sub-second component is not superstition: `os.time` has one-second resolution, so two games begun
-- in the same second would be the same game. Harmless, but confusing to run into, and a fraction of a
-- frame's timer costs nothing to fold in. Absent under a headless harness, where the clock alone does.
function Seed.roll()
    local frac = (love and love.timer and love.timer.getTime()) or 0
    return Seed.mix(os.time(), math.floor(frac * 1000))
end

-- THIS SAVE'S SEED, minted on demand.
--
-- Lazy for the same reason Player.authorId is: a save written before seeds existed has none, and the
-- honest answer for it is to mint one and keep it rather than to have every load look like a different
-- world. A fresh player already carries one (Player.new), so this is the migration path and nothing else.
function Seed.base(player)
    if not player then return 0 end
    if not player.seed then player.seed = Seed.roll() end
    return player.seed
end

-- THE SEED FOR THE LAP THE PLAYER IS ON. Lap zero is the save's own seed; every New Game+ folds the lap
-- number in.
--
-- DERIVED RATHER THAN STORED, and that is the whole reason one number can describe a whole save. `ngPlus`
-- is already persisted (models/save.lua), so the lap's seed is re-derivable on every load and cannot
-- drift from what it was -- where a second stored field could, and would do it silently. It also means a
-- seed that is shared reproduces the second lap as faithfully as the first.
function Seed.lap(player)
    local base = Seed.base(player)
    local lap = (player and player.ngPlus) or 0
    if lap == 0 then return base end
    return Seed.mix(base, lap)
end

-- THE NEXT DESCENT'S SEED, and the counter that keeps two runs in one lap from being one run twice.
--
-- Called by Descent.new when nobody pinned a seed. It ADVANCES the count, which makes it the one
-- function here that writes: a run is a thing that happens, and "which run is this" cannot be derived
-- from anything else the player owns -- the run itself is thrown away when it ends.
--
-- Safe to call exactly where it is called. `Descent.new(player)` is only reached when there is no run to
-- resume (Lua's `or` is lazy, so `run or Descent.new(player)` does not mint one it then discards), so
-- the count tracks descents actually begun.
function Seed.run(player)
    if not player then return Seed.roll() end
    player.runsStarted = (player.runsStarted or 0) + 1
    return Seed.mix(Seed.lap(player), player.runsStarted)
end

-- ---------------------------------------------------------------------------
-- Saying it out loud (development builds only)
-- ---------------------------------------------------------------------------

-- THE NUMBERS THAT REPRODUCE WHAT IS ON SCREEN, as one line, or nil in a release build.
--
-- DEBUG-ONLY BY AUTHOR CALL, and gated HERE rather than at each drawing site (models/debug.lua). One
-- choke point means a second surface that wants the readout cannot leak it by forgetting the `if`, and
-- the rule debug.lua sets stays intact: the affordance makes development easier and is never the only
-- way something works -- nothing in the game reads this string.
--
-- WHAT IT NAMES is exactly what somebody would have to be told to stand where the reader is standing:
--
--   seed   the save's own number. Reproduces the whole playthrough, every lap of it.
--   lap    which New Game+ this is. Omitted at zero, where the lap's seed IS the save's.
--   rift   the descent's seed, which is what a floor's ground is dealt from. Shown only in a run.
--   floor  the other half of that key, since a board is (rift, depth) and nothing else.
--
-- A run index is deliberately left out: `rift` already identifies the descent, and a second number
-- that only counts would be one more thing to copy into a bug report and get wrong.
function Seed.line(player, run)
    if not require("models.debug").enabled then return nil end

    local parts = { "seed " .. Seed.base(player) }
    local lap = (player and player.ngPlus) or 0
    if lap > 0 then parts[#parts + 1] = "lap " .. lap end
    if run then
        parts[#parts + 1] = "rift " .. (run.seed or 0)
        parts[#parts + 1] = "floor " .. (run.floor or 1)
    end
    return table.concat(parts, "  ·  ")
end

return Seed
