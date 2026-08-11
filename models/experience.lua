-- EXPERIENCE: what levels a body in the descent, one action at a time.
--
-- models/growth.lua opens by stating that characters do not carry individual XP -- every roster member's
-- level tracks the player's global prestige (Player.syncLevels). That is still true of THE CAMPAIGN, and
-- nothing here changes it. It stopped being true of the descent, which is a separate game mode now: a run
-- musters a company at the mouth and banks nothing on the way out (models/descent.lua), so there is no
-- prestige climbing behind it to hang a level on. A clean run walks in at level 1 and has to grow on the
-- way down or not at all.
--
-- WHAT THIS OWNS IS THE TRIGGER, AND ONLY THE TRIGGER. Growth still decides what a level is worth and
-- who a body becomes -- Growth.resolve levels a character to a target and apportions the stat gains
-- across everything it has been casting since the last one, so a knight who keeps throwing Fireball still
-- grows into a battlemage. This file answers the one question Growth does not: when.
--
-- HOW IT STAYS OUT OF THE CAMPAIGN'S WAY, without a mode flag threaded through combat. Combat awards XP
-- unconditionally (Combat.awardTechnique's call site, and the felling blow in dealFlatDamage) -- but
-- awarding is just a counter going up on a character. Only the descent ever RESOLVES that counter into
-- levels (Experience.resolveParty, called from states/game.lua's battle end when a run is under way). In
-- the campaign `char.xp` is a number nobody reads. So the two ladders cannot collide: there is no branch
-- in combat that could be wrong, because combat does not know which mode it is in and does not need to.
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
-- STEP is anchored on the descent's own ladder rather than picked. Descent.floorLevel fights the seventh
-- circle at level 13 (LEVEL_PER_FLOOR = 2, floor 7 -> 13), and a floor is roughly six or seven fights in
-- which a body acts about seven times and takes something over one kill -- call it 70 experience per body
-- per floor, 490 across a full run. Reaching level 13 on the triangle costs STEP x 78, so STEP = 6 puts
-- the seventh circle at 468: a company that fights its way down arrives at the bottom at about the level
-- the bottom is built for, and one that skips fights arrives under it. tests/experience_spec.lua pins the
-- arithmetic; models/balance.lua is where the claim about what a floor pays gets re-measured.
Experience.STEP = 6

-- Total experience needed to have REACHED `level`. Level 1 costs nothing -- everybody starts there.
function Experience.totalFor(level)
    local l = math.max(1, math.min(Growth.LEVEL_CAP, level or 1))
    return Experience.STEP * l * (l - 1) / 2
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

-- Resolve a whole company, returning the list of members that advanced. THE DESCENT'S ONLY CALL SITE
-- (states/game.lua, at the end of a battle in a run) and therefore the entire boundary between "the
-- campaign counts experience it never spends" and "the descent spends it".
function Experience.resolveParty(chars)
    local advanced = {}
    for _, char in ipairs(chars or {}) do
        local summary = Experience.resolve(char)
        if summary then advanced[#advanced + 1] = summary end
    end
    return advanced
end

return Experience
