-- EXPERIENCE: what levels a body, one action at a time. THE ONLY LADDER IN THE GAME.
--
-- It was not always. This file was written for the descent alone -- a separate mode that musters a
-- company at the mouth and banks nothing on the way out, so there was no prestige climbing behind it to
-- hang a level on. The campaign levelled off the player's global prestige instead (Player.syncLevels):
-- every roster member pinned to one number, all advancing together the moment a quest paid out.
--
-- That is gone. Prestige was one number doing two jobs and it did neither well -- it made every body in
-- the company interchangeable at a given moment, so a fresh recruit carrying a veteran's kit was the
-- same unit, and it meant a day spent anywhere but on a quest grew nobody. Under a deadline
-- (models/calendar.lua) the second half is fatal: an expedition that forages has to still be worth
-- taking. So the gate came out, `Player.syncLevels` and `Player.addPrestige` went with it, and this is
-- now what moves every level in the game, in both modes.
--
-- WHAT THIS OWNS IS THE TRIGGER, AND ONLY THE TRIGGER. Growth still decides what a level is worth and
-- who a body becomes -- Growth.resolve levels a character to a target and apportions the stat gains
-- across everything it has been casting since the last one, so a knight who keeps throwing Fireball still
-- grows into a battlemage. This file answers the one question Growth does not: when.
--
-- THE ONE SEAM THAT RESOLVES. Combat awards experience as it happens (Experience.credit, from
-- Combat.useItem and the felling blow in dealFlatDamage), which is only a counter going up. Turning
-- that counter into levels happens in exactly one place -- states/game.lua's post-fight seam, which
-- every won fight already passes through -- plus a catch-up on load (Player.resolveLevels). Keeping
-- resolution to one seam is what lets combat stay ignorant of modes and of rosters.
--
-- Pure model -- no love.graphics -- so it loads under the headless runner.

local Growth = require("models.growth")

local Experience = {}

-- WHAT EARNS IT. Acting, FFT-style: a body grows by doing, not by being present, which is what keeps a
-- healer and a scout levelling alongside the sword. Both knobs are authored in the unit they are counted
-- in -- one action, one felling blow -- and the curve below converts.
--
-- A kill is worth four actions. High enough that finishing a fight is worth taking, low enough that the
-- body that lands the last blow does not pull three levels clear of the one that softened the target:
-- across a floor a company spreads its kills, and the actions are the bulk of the income either way.
Experience.PER_ACTION = 1
Experience.PER_FELLING = 4

-- THE CURVE. Experience to climb one level is STEP x the level being left, so the cost of a level rises
-- linearly and the cumulative cost of reaching level L is triangular: STEP x L x (L-1) / 2.
--
-- STEP IS ANCHORED ON A MEASUREMENT, and it had to be re-anchored when this file stopped being the
-- descent's private ladder and became the campaign's. `. board-report 12 xp` fights every combat and
-- elite on a dozen rolled boards through models/autobattle.lua -- the real loop, the real plan, the
-- real ordering -- with a company held at parity with the day, and reads what combat actually banked:
--
--     22.1 experience a body a day, i.e. per expedition
--     x 40 days (Calendar.DAYS) = 882 over a campaign that fights everything it meets
--
-- The old value of 6 was anchored on the descent's seven-floor ladder and says so in the note it
-- replaced. Carried into the campaign it put that 882 at level 17, five short of the world's closing
-- level of 22 -- so a player who fought every fight on every board still arrived at the last day
-- outmatched, which is not a deadline, it is a wall.
--
-- STEP = 3 puts the same 882 at level 24. That is the CEILING, reached only by clearing every board
-- entire; a player who takes the seventy percent of fights a real run takes lands near 20 -- above the
-- ordinary road (which spawns around 19 after Growth's lag) and a shade under the finale. Which is the
-- shape the whole calendar is for: keeping pace is possible, and squandering days is felt.
--
-- ESTIMATING THIS WOULD HAVE BEEN A DISASTER, and nearly was: the figure carried in the design notes
-- was 44 a day, twice the truth. tests/experience_spec.lua pins the arithmetic, and the number above is
-- reproducible rather than remembered.
Experience.STEP = 3

-- THE DESCENT KEEPS ITS OWN, and the two are separate constants because the modes are separate games.
--
-- The descent's ladder is anchored on the BOTTOM, and the arithmetic is worth writing down because the
-- constant is meaningless without it. A floor is about six fights, each paying a body roughly twelve
-- (seven actions at PER_ACTION, a little over one felling at PER_FELLING), so a floor is ~72 and the
-- fifteen floors of a whole descent are ~1080. The Hollow Crown fights at Descent.floorLevel of the
-- bottom floor, which is 15. Reaching level 15 costs STEP x 15 x 14 / 2 = 105 x STEP, and level 16
-- costs 120 x STEP -- so a step of ten puts a company that fights its way down at exactly the level the
-- bottom is built for, and one short of overshooting it.
--
-- IT WAS SIX, for an eight-floor descent whose seventh circle fought at level 13 off ~490 earned. When a
-- circle became a stratum the mode went to fifteen floors, which is twice the fighting -- so leaving the
-- step alone would have handed the Crown a company five levels above it. The floor ladder got gentler
-- (Descent.LEVEL_PER_FLOOR fell to one) and this got steeper, and between them the envelope the growth
-- tables and the shelf were built against did not move.
--
-- Nothing about that reasoning changed when the campaign's did, and it must not be dragged along: the
-- campaign re-anchored because it acquired a deadline and a forty-day budget, which the descent has
-- neither of. Sharing one constant meant every campaign retune silently re-tuned the post-game too --
-- which is the "second master" the decision to leave the descent alone was made to avoid. So the step
-- is a PARAMETER on everything below, defaulting to the campaign's, and models/descent.lua names this
-- one at its own resolve.
Experience.DESCENT_STEP = 10

-- Total experience needed to have REACHED `level`. Level 1 costs nothing -- everybody starts there.
function Experience.totalFor(level, step)
    local l = math.max(1, math.min(Growth.LEVEL_CAP, level or 1))
    return (step or Experience.STEP) * l * (l - 1) / 2
end

-- The level `xp` entitles a body to, capped by Growth.LEVEL_CAP -- the same ceiling the prestige ladder
-- respects, so neither mode can produce a character the growth tables have no row for.
function Experience.levelFor(xp, step)
    local total = xp or 0
    local level = 1
    while level < Growth.LEVEL_CAP and total >= Experience.totalFor(level + 1, step) do
        level = level + 1
    end
    return level
end

-- How much further to the next level, as `into, span` -- what a bar fills. Nil at the cap, which has no
-- next level and must not render as a bar frozen just short of full (Growth.prestigeIntoLevel returns
-- nil for the same reason, and a readout that reads one should be able to read the other).
function Experience.intoLevel(xp, step)
    local level = Experience.levelFor(xp, step)
    if level >= Growth.LEVEL_CAP then return nil end
    local base = Experience.totalFor(level, step)
    return (xp or 0) - base, Experience.totalFor(level + 1, step) - base
end

-- Bank experience on a body. Total lifetime, never a per-level remainder: the level is a pure function
-- of the total (Experience.levelFor), so there is no second number that can drift out of step with it
-- and nothing to migrate if the curve is ever retuned.
--
-- Called from combat on every action that connects and on every felling blow. Deliberately cheap and
-- deliberately unconditional -- see the file header on why there is no mode check here.
function Experience.award(char, amount)
    if not char or not amount or amount <= 0 then return end
    char.xp = (char.xp or 0) + amount
end

-- Award, and keep a per-character tally of what THIS fight paid, on the combat object. Combat's own
-- call sites use this rather than Experience.award directly.
--
-- The tally exists for one reader -- Experience.payBench, which cannot know what the field earned
-- without it -- and it lives on `combat` beside `techniqueByActor`, which is there for the same kind of
-- reason. Keyed by the CHARACTER rather than the unit: a body that rotates off the board and back on is
-- one earner, and units are per-battle objects while characters are the thing that persists.
function Experience.credit(combat, char, amount)
    Experience.award(char, amount)
    if not (combat and char) or not amount or amount <= 0 then return end
    combat.xpByChar = combat.xpByChar or {}
    combat.xpByChar[char] = (combat.xpByChar[char] or 0) + amount
end

-- What a body that did not take the field earns for the fight, as a share of what the average member
-- who DID earned.
--
-- Not zero, and the reason is a rule that predates this: the roster IS the company, it travels whole,
-- and Combat.rotate makes swapping the bench in a live tactical decision mid-fight (docs/deployment.md).
-- Bodies that rot on the bench make that mechanic decorative -- nobody rotates in a member four levels
-- behind -- and they push the player toward fielding the same four all campaign, which is the exact
-- shape the rotating field was built to break.
--
-- Not one, either. Standing on the board is where the risk is: a fielded body spends health, spends
-- consumables, and can be the one that goes down and takes a wound out of the run. Paying the bench the
-- same as the field would price that risk at nothing.
Experience.BENCH_SHARE = 0.5

-- Pay the bench. `fielded` is the list of characters that actually stood on the board, `roster` the
-- whole company; `earned` maps a character to what it banked in the fight just finished.
--
-- Averaged over the FIELD rather than over the roster, so the share does not shrink as the company
-- grows -- a tenth companion should not quietly halve what everyone on the bench is paid.
--
-- Returns the amount each benched body received, for a caller that wants to report it.
function Experience.payBench(roster, fielded, earned)
    local onField = {}
    local total, n = 0, 0
    for _, char in ipairs(fielded or {}) do
        onField[char] = true
        total = total + ((earned and earned[char]) or 0)
        n = n + 1
    end
    if n == 0 then return 0 end
    local share = math.floor(total / n * Experience.BENCH_SHARE)
    if share <= 0 then return 0 end
    for _, char in ipairs(roster or {}) do
        if not onField[char] then Experience.award(char, share) end
    end
    return share
end

-- WHAT THE FIGHT PAID, per body, as the rows a victory readout draws its bars from. `earned` is
-- `combat.xpByChar` -- what each character banked in the fight just finished -- and `char.xp` is
-- already the total AFTER those awards (Experience.credit awards as it tallies), so the fight's
-- starting point is the difference. Both ends are reported because a bar has to fill from somewhere.
--
-- Here rather than in the panel, and here rather than in states/battle.lua, for two reasons: the
-- arithmetic is the curve's (a level is a pure function of the total, and only this file knows the
-- function), and a spec can read this while it cannot construct a panel -- ui modules pull fonts at
-- load and the headless runner has no love.graphics.
--
-- Sorted by what each body took, biggest first, ties broken by name: `pairs` over a character-keyed
-- table would otherwise reshuffle the same four bodies between two plays of the same fight.
function Experience.report(earned, step)
    local rows = {}
    for char, gain in pairs(earned or {}) do
        if char and (gain or 0) > 0 then
            local to = char.xp or 0
            local from = math.max(0, to - gain)
            rows[#rows + 1] = {
                char = char,
                name = char.name or char.id or "?",
                gain = gain,
                from = from,
                to = to,
                fromLevel = Experience.levelFor(from, step),
                toLevel = Experience.levelFor(to, step),
            }
        end
    end
    table.sort(rows, function(a, b)
        if a.gain ~= b.gain then return a.gain > b.gain end
        return a.name < b.name
    end)
    return rows
end

-- The experience a body joining the company mid-campaign arrives with: the MEDIAN of the company it is
-- joining. Player.recruit's rule, kept here beside the curve it is expressed in.
--
-- Median rather than either extreme, and both extremes were considered. Level 1 is what the character
-- would naturally be, and it is a body nobody ever fields -- a companion who arrives unusable is a
-- reward the player cannot take, and under a deadline they will never get the spare days to fix it.
-- Matching the best member is a free ride that makes a late recruit strictly better than an early one.
-- The median is the company as it actually is: the newcomer is immediately fieldable and still behind
-- the veterans who earned their place.
--
-- An empty company returns 0, which is level 1 -- correct for the avatar, who joins nothing.
function Experience.medianOf(roster)
    local xs = {}
    for _, char in ipairs(roster or {}) do xs[#xs + 1] = char.xp or 0 end
    if #xs == 0 then return 0 end
    table.sort(xs)
    local mid = math.floor((#xs + 1) / 2)
    return xs[mid]
end

-- Turn banked experience into levels, through Growth. Returns Growth.resolve's summary
-- ({ char, fromLevel, toLevel, class, gains, ... }) when the body actually advanced, else nil -- the same
-- shape the post-quest advancement overlay already reads, so a descent's level-up needs no second
-- reporting format.
--
-- Idempotent: Growth.resolve is a no-op on a character already at its target, so calling this after every
-- battle costs nothing on a body that has not earned a level since the last one.
function Experience.resolve(char, step)
    if not char then return nil end
    return Growth.resolve(char, Experience.levelFor(char.xp, step))
end

-- Resolve a whole company, returning the list of members that advanced. THE DESCENT'S ONLY CALL SITE
-- (states/game.lua, at the end of a battle in a run) and therefore the entire boundary between "the
-- campaign counts experience it never spends" and "the descent spends it".
function Experience.resolveParty(chars, step)
    local advanced = {}
    for _, char in ipairs(chars or {}) do
        local summary = Experience.resolve(char, step)
        if summary then advanced[#advanced + 1] = summary end
    end
    return advanced
end

return Experience
