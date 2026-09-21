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

-- THE CURVE IS FLAT: every level costs STEP, at every level. ALL of the control is in the AWARD
-- (Experience.rewardScale), and none of it is here.
--
-- FINAL FANTASY TACTICS' ARRANGEMENT, adopted deliberately after trying the other two. A level there
-- costs 100 experience whether it is your second or your fiftieth; what varies is what an ACTION pays,
-- which is scaled by how far the thing you acted on sits above or below you. Hit something well under
-- your level and you are paid about one point. The flat table is not an oversight -- it is what lets
-- the scaling be the whole rule.
--
-- WHY NOT A RISING CURVE, having shipped two. Triangular was the original and a farmer beats it: the
-- twentieth lap of a cheap floor pays what the first did while the level it buys has only got linearly
-- dearer. Geometric fixed that and broke something worse. The danger ladder down here is LINEAR -- one
-- level a floor (Descent.LEVEL_PER_FLOOR) -- and a geometric cost against a linear ramp diverges by
-- construction: the cheap early levels go by fast and the dear late ones do not, so a company playing
-- the mode exactly as designed ran SIX levels over its own ground by floor two. Measured, and caught by
-- tests/reward_scale_spec walking the ramp. Every grace band wide enough to stop taxing that company
-- was also wide enough to let it farm.
--
-- FLAT AND SCALED IS SELF-STABILISING, which is the property the other two do not have and the reason
-- this is the right borrow. A company that pulls ahead of its ground earns less and slows; one that
-- falls behind earns full and catches up. So the party LEVEL TRACKS THE FLOOR rather than racing it,
-- at whatever gap the falloff and the income settle on -- and the whole question of "does the curve
-- keep pace with the ladder" stops being a thing anybody has to tune, because it answers itself.
--
-- WHAT WE DO NOT BORROW IS FFT'S TREATMENT OF JP. There, job points are flat per action and are NOT
-- level-scaled, which is exactly why grinding weak enemies for JP is a known strategy in that game.
-- Technique is scaled here on the same curve as experience (Combat.scaledAward) -- see
-- Class.TECHNIQUE_PER_ACTION. The hole FFT leaves open is the one this was reported through.
--
-- ONE STEP, AND IT USED TO BE TWO. This file carried a second constant -- DESCENT_STEP, ten against the
-- campaign's three -- on the reasoning that the descent and the quest board were separate games, and
-- that sharing one number meant every campaign retune silently re-tuned the post-game. That reasoning
-- died with the mode it was about. The Quest Board is retired (models/building.lua's RETIRED) and the
-- descent IS the campaign now, so the second master the split was built to serve no longer exists, and
-- all the split still bought was a branch every caller had to remember.
--
-- WHICH THEY DID NOT. The branch read `game.descent and DESCENT_STEP or nil`, and the two places that
-- have no descent to read got the cheap ladder by default:
--
--   * the prologue banks its experience before a run exists, so Act 0 cashed out at three and handed the
--     Gate a company at level 8 against a first floor that fights at 3 (Descent.OPENING_DANGER). Every
--     marker on it read as beneath them -- and because Growth.resolve never levels a body down, that
--     head start then cost four floors during which nobody gained a level at all;
--   * Player.resolveLevels passed no step, so a mid-descent save re-levelled its whole roster on the
--     cheap curve every time it loaded.
--
-- A ladder that has to be named correctly at every seam is a ladder that will be named wrongly at one of
-- them. There is one now, and no seam can pick the wrong one.
--
-- STEP IS ANCHORED ON THE BOTTOM OF THE DESCENT, and the arithmetic is worth writing down because the
-- constant is meaningless without it. A floor is about six fights, each paying a body roughly twelve
-- (seven actions at PER_ACTION, a little over one felling at PER_FELLING), so a floor is ~72 and the
-- fifteen floors of a whole descent are ~1080. The Hollow Crown fights at Descent.floorLevel of the
-- bottom floor, which is 15. Reaching level 15 costs STEP x 15 x 14 / 2 = 105 x STEP, and level 16 costs
-- 120 x STEP -- so a step of ten puts a company that fights its way down at exactly the level the bottom
-- is built for, and one short of overshooting it.
--
-- IT WAS SIX, for an eight-floor descent whose seventh circle fought at level 13 off ~490 earned. When a
-- circle became a stratum the mode went to fifteen floors, which is twice the fighting -- so leaving the
-- step alone would have handed the Crown a company five levels above it. The floor ladder got gentler
-- (Descent.LEVEL_PER_FLOOR fell to one) and this got steeper, and between them the envelope the growth
-- tables and the shelf were built against did not move.
--
-- AND IT PRICES ACT 0 CORRECTLY, which is the same ladder read at its other end. The prologue's four
-- fights pay a two-body company around eighty a head, which is level 4 here and was level 8 at three --
-- so the company arrives at the mouth of the Gate a level above the danger the first floor fights at
-- rather than five above it. The tutorial's income was never the defect; the curve it was read on was.
--
-- ESTIMATING THIS WOULD HAVE BEEN A DISASTER, and the campaign's own step was estimated once at twice
-- the truth before it was measured. tests/experience_spec.lua pins the arithmetic and
-- tests/descent_level_spec.lua walks all fifteen floors against it, so the number above is reproducible
-- rather than remembered.
--
-- RE-ANCHORED ON A MEASURED FLOOR, AND THEN ON THE EQUILIBRIUM. Everything above was worked against "a
-- floor is about six fights", which was Descent.FLOOR_FIGHTS read at the time and is not what a floor
-- costs: the prowl deals a fight per PROWL_STEPS of WALKING, and a greedy tour of every content cell on
-- a rolled floor runs 78 steps at the top and 90 at the bottom -- 6.9 fights a floor rising to 8.6. A
-- worked route, which re-treads for a locked cache and walks back to the stair, is nearer ten a floor,
-- which at twelve a fight is 120 nominal.
--
-- NINETY-SIX IS A FLOOR TOURED, and that is the whole derivation: a level costs exactly what one
-- floor pays at FULL rate, so a company keeping pace with its ground gains the one level a floor that
-- the ground gains, and the gap neither opens nor closes. The ladder and the ramp are parallel by
-- construction rather than by tuning.
--
-- SOLVED AT THE TOUR RATE AND NOT THE WORKED ONE, deliberately. Pricing a level at a WORKED floor
-- (120) leaves a toured one paying under a level, so the careful player falls behind the ground for
-- being careful. Pricing it at the tour makes the thorough player gain a little -- and that surplus is
-- what the falloff is FOR: they pull one to two levels ahead, earnings throttle, and they settle
-- there. The error runs in the forgiving direction and the loop absorbs it.
--
-- WHAT THAT LANDS, walked floor by floor against the real spawn level: the company leaves Act 0 five
-- sixths of the way to its second level -- so the first fight of floor one is a level-up -- tracks the
-- stock on the board within a level or two the whole way down, and arrives at the Crown around 16 or
-- 17 against a bottom that fights at 17. tests/reward_scale_spec runs that simulation at three
-- different rates rather than restating any of it.
Experience.STEP = 96

-- Total experience needed to have REACHED `level`. Level 1 costs nothing -- everybody starts there.
function Experience.totalFor(level)
    local l = math.max(1, math.min(Growth.LEVEL_CAP, level or 1))
    return Experience.STEP * (l - 1)
end

-- ---------------------------------------------------------------------------
-- WHAT A FIGHT IS WORTH AGAINST WHAT YOU ARE
-- ---------------------------------------------------------------------------
--
-- The share of its full award a fight pays a body `earnerLevel` standing against opposition at
-- `oppositionLevel`. One over an even fight, falling away once the company has outgrown the ground.
--
-- THE FLOOR IS A PLACE AND IT RE-ARMS, which is what makes this necessary rather than tidy. A company
-- can walk floor one for as long as it likes and the monsters come back every time (Descent.rearmFloor
-- -- Wizardry's own split, and the right one). What must not come back is the PAY: in Wizardry a level
-- one maze is worth nothing to a party that has been to ten, and that is the whole reason nobody farms
-- it. Without this the shallow end is an infinite, safe, if slow, source of both ladders.
--
-- A GRACE BAND FIRST, and it is the part that keeps honest play whole. A company that fights its way
-- down LEADS the ground it is standing on for most of the descent, draws level around floor twelve and
-- finishes a little behind -- so a flat per-level falloff would tax the intended curve hardest exactly
-- where the mode is hardest to keep up with, and a company playing it as designed would be paying a
-- penalty for doing so.
--
-- ONE, AND IT WENT THREE -> FIVE -> ONE, which is worth recording because the first two were chasing a
-- problem that belonged to the CURVE. While the cost curve was geometric it outran the linear danger
-- ladder by construction, so honest play sat four, then six levels over its own ground and the grace
-- had to keep widening to avoid taxing it -- each widening making the farming rule weaker. Flattening
-- the curve removed the divergence at its source (see THE CURVE IS FLAT above) and the band no longer
-- has to cover a drift that does not happen.
--
-- So this is small on purpose. FFT has no grace band at all -- one level above the target already pays
-- you less there -- and one level is the smallest concession that stops a company being penalised for
-- a single level of ordinary drift, which would read as arbitrary rather than as a rule.
--
-- IT IS ALSO HALF OF WHERE THE EQUILIBRIUM SITS, so it is not free and must not be widened casually:
-- the party settles at GRACE plus log(STEP/income)/log(FALLOFF) levels over the ground, which is two
-- at these numbers. Widen this and the whole ramp rises with it.
--
-- MEASURED AGAINST WHAT ACTUALLY SPAWNS, not against the ladder: ordinary stock is LAGGED under the
-- floor's own danger (Growth.ENEMY_LEVEL_LAG) and Combat.oppositionLevel reads real units, so the gap
-- in play runs about a level wider than the gap on paper. tests/reward_scale_spec simulates the whole
-- descent through Growth.combatantLevel rather than restating any of this.
--
-- ...AND GEOMETRIC DECAY AFTER IT, never a cliff. A hard cutoff makes one level of drift the difference
-- between full pay and nothing, which reads as the game breaking rather than as a rule. At 0.65 a body
-- four levels past the grace still earns a fifth, and the level-15 company farming floor one -- twelve
-- levels up, nine past the grace -- earns two per cent of what the fight is worth. Slow enough to be
-- pointless, never zero, and never a wall anybody can be surprised by.
Experience.REWARD_GRACE = 1
Experience.REWARD_FALLOFF = 0.65

function Experience.rewardScale(earnerLevel, oppositionLevel)
    local gap = (earnerLevel or 1) - (oppositionLevel or 1) - Experience.REWARD_GRACE
    if gap <= 0 then return 1 end
    return Experience.REWARD_FALLOFF ^ gap
end

-- The level `xp` entitles a body to, capped by Growth.LEVEL_CAP -- the same ceiling the prestige ladder
-- respects, so neither mode can produce a character the growth tables have no row for.
function Experience.levelFor(xp)
    local total = xp or 0
    local level = 1
    while level < Growth.LEVEL_CAP and total >= Experience.totalFor(level + 1) do
        level = level + 1
    end
    return level
end

-- How much further to the next level, as `into, span` -- what a bar fills. Nil at the cap, which has no
-- next level and must not render as a bar frozen just short of full (Growth.prestigeIntoLevel returns
-- nil for the same reason, and a readout that reads one should be able to read the other).
function Experience.intoLevel(xp)
    local level = Experience.levelFor(xp)
    if level >= Growth.LEVEL_CAP then return nil end
    local base = Experience.totalFor(level)
    return (xp or 0) - base, Experience.totalFor(level + 1) - base
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
function Experience.report(earned)
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
                fromLevel = Experience.levelFor(from),
                toLevel = Experience.levelFor(to),
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
function Experience.resolve(char)
    if not char then return nil end
    return Growth.resolve(char, Experience.levelFor(char.xp))
end

-- Resolve a whole company, returning the list of members that advanced. ONE CALL SITE -- states/game
-- .lua, at the end of every won fight -- which is what keeps the trigger from having to know which mode
-- it is standing in, or which floor, or which curve. There is only one curve now (see STEP).
function Experience.resolveParty(chars)
    local advanced = {}
    for _, char in ipairs(chars or {}) do
        local summary = Experience.resolve(char)
        if summary then advanced[#advanced + 1] = summary end
    end
    return advanced
end

return Experience
