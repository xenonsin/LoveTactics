-- Class logic. Blueprints live in data/classes/<id>.lua (see docs/classes.md, "Disciplines",
-- and the authoring slate in docs/disciplines-plan.md).
--
-- A discipline is a shop taxonomy like `class`: unlocking it adds a locked deeper cut of items to its
-- parent vendor shelf(es). Arity is the whole distinction -- one parent is a subclass, two is a
-- multiclass -- and the gate is earned advancement: a multiclass unlocks only once the player already
-- holds a subclass of EACH parent (which is what opens its capstone quest).
--
-- Pure logic (no love.graphics), so it loads under the headless tests.

local Registry = require("models.registry")
local Character = require("models.character")
local Locale = require("models.locale")  -- the catalog seam a class's authored blurb is read through

local Class = {}

Class.defs = Registry.load("data/classes", "data.classes")

-- The parent classes of `id` -- the classes it is earned FROM. {} for a root or an unknown id.
--
-- READ OFF `requires`, WHICH IS NOW THE ONLY FIELD. A blueprint used to carry its parents in `classes`
-- and its gate in `requiredLevel`, and the two could not be reconciled: every crossing named two
-- parents and gated on ONE of them, with the other half living as an implicit rule inside isUnlocked.
-- Thirty-two of the thirty-eight gates were `-- pending` on top of that. One field cannot disagree with
-- itself, and a gate that names both halves is a gate somebody can read. See docs/class-fold.md.
--
-- SORTED, because `requires` is a map and `pairs` promises no order -- and this answer is drawn on
-- screen ("Alchemist x Priest") and iterated when the forge bills a house, both of which must be the
-- same twice running. The order is alphabetical rather than authored, which is the one thing the
-- collapse cost: `classes` was a list and could say which parent came first.
function Class.parents(id)
    local def = id and Class.defs[id]
    if not def then return {} end
    local out = {}
    for class in pairs(def.requires or {}) do out[#out + 1] = class end
    table.sort(out)
    return out
end

-- Arity: 1 = subclass, 2 = multiclass, 0 = a ROOT or an unknown id -- ask Class.isRoot to tell
-- those two apart, since one is the top of the ladder and the other is not on it.
function Class.arity(id)
    return #Class.parents(id)
end

-- Is `id` a ROOT class -- one of the seven a body holds from the first morning, or the creature bucket?
--
-- READ OFF THE BLUEPRINT RATHER THAN LISTED, which is the whole point of folding the seven into the
-- same folder as the other thirty-eight (docs/class-fold.md). A root is a class with nothing standing
-- above it, and "nothing stands above it" is exactly what an empty `classes` says. A second table
-- naming the seven would be a list that could disagree with the files, which is the shape of every
-- drift this fold exists to end.
--
-- False for an unknown id, so a stale tag is never mistaken for the top of the ladder.
function Class.isRoot(id)
    local def = id and Class.defs[id]
    return def ~= nil and not next(def.requires or {})
end

-- Is `id` an EARNED class -- a real class with something standing above it, which is to say anything
-- that is not a root?
--
-- The exact complement of isRoot over the classes that EXIST, and it is its own function because the
-- compound ("a real class, and not a root") is asked in nine places -- the forge's ceiling and its
-- material bill, the shelf's lock, the market's standing rack, the tooltip's tint, three report tools
-- -- and every one of them means the same sentence: did you play for this, or did the city sell it to
-- you. Written out nine times it is nine chances to drop the existence half and answer true for a
-- stale tag. See docs/class-fold.md.
function Class.isEarned(id)
    local def = id and Class.defs[id]
    return def ~= nil and next(def.requires or {}) ~= nil
end

-- THE HIGHEST CLASS LEVEL `id` ASKS FOR: 0 for a root, for a classless thing, or for an unknown tag.
--
-- `requires` is a map of parent class to the rung that parent must stand at -- Warden asks knight 15 AND
-- hunter 15 -- and every reader so far has wanted the whole map: may I have this, and what is missing.
-- This wants the one number the map implies, which is how far into the game the class is AT ALL, quoted
-- on the same 1..CLASS_LEVEL_CAP ladder a rung is. The MAX and not a sum or an average: a crossing is
-- reachable once its DEAREST condition is paid, and the other half being cheap does not make it earlier.
--
-- It exists because the rift had no version of the shelf's lock. A vendor greys a crossing's stock until
-- it is unlocked (models/vendor.lua) and the drop pool ranked a find by what it was WORTH and by nothing
-- else -- so a Warden charm with small numbers on it fell out of floor one, eight rungs before anybody
-- could have earned the class it belongs to. See Spoils.depthOf.
function Class.gateLevel(id)
    local def = id and Class.defs[id]
    local n = 0
    for _, need in pairs(def and def.requires or {}) do
        if type(need) == "number" and need > n then n = need end
    end
    return n
end

-- The ROOT classes `id` descends from, as a list. A root answers itself; an earned class answers its
-- parents (which are roots -- tests/class_ladder_spec pins that). {} for an unknown id.
--
-- The one question the fold cannot answer by reading a single field, and the reason it does not need to
-- be authored: "which house is this from" is a property of the CLASS, not of each item wearing it, so it
-- is asked of the blueprint once rather than stamped on six hundred files. An earlier cut of the plan
-- gave every crossing an authored `home` root for this; nothing turned out to want a single answer.
function Class.rootsOf(id)
    if not (id and Class.defs[id]) then return {} end
    if Class.isRoot(id) then return { id } end
    local out = {}
    for _, parent in ipairs(Class.parents(id)) do out[#out + 1] = parent end
    return out
end

-- Does class `id` sit under root `root` -- is it that root, or something earned from it?
function Class.descendsFrom(id, root)
    for _, r in ipairs(Class.rootsOf(id)) do
        if r == root then return true end
    end
    return false
end

-- Is `id` a class a body can actually take up? Everything except the creature bucket, which is a name
-- for kit that belongs to no job rather than a job (data/classes/creature.lua). The one question
-- every spec that asks a class to behave like a career has to ask first.
function Class.isPlayable(id)
    local def = id and Class.defs[id]
    return def ~= nil and def.playable ~= false
end

-- The set of PLAYABLE root classes -- the seven the city was built on -- as { id = true }.
--
-- This is what `Item.CLASSES` was, and the reason it is a function over the blueprints rather than a
-- table of its own is the whole argument of the fold: a literal list of the seven is a second place the
-- set is stated, and two statements of one set is how `class` and `discipline` came to be two axes in
-- the first place. Ask the files.
--
-- CREATURE IS OUT, and every caller wants it out. "The seven" is always asked in a career's sense --
-- which shelves arm a newcomer, which racks a companion opens, which houses the weapon families are
-- cut across -- and the creature bucket answers none of those. Class.isRoot is the wider question
-- when somebody genuinely means all eight.
--
-- Returns a fresh table, so a caller cannot mutate the answer out from under the next one.
function Class.roots()
    local out = {}
    for id, def in pairs(Class.defs) do
        if not next(def.requires or {}) and def.playable ~= false then out[id] = true end
    end
    return out
end

-- The display name of discipline `id` ("Ninja"), or nil when the id is absent or unknown. The single
-- place the UI turns a stored id into words, so every surface that names an item's discipline -- the
-- tooltip's row, the shop shelf, the forge -- says it the same way, and a stale id on an item prints
-- nothing rather than leaking a raw slug into the panel.
function Class.displayName(id)
    local def = id and Class.defs[id]
    if not def then return nil end
    return def.name or id
end

-- The one-or-two sentence blurb a shop shows for discipline `id`: what the path IS, and the mechanic
-- it is built on. Nil for an unknown id, and for a blueprint that has not written one yet.
--
-- Authored on the blueprint rather than derived, and read by ui/panels/shop.lua's section detail. A
-- locked path collapses to its header on the shelf, so the only thing the player can read about it
-- before earning it is that pane -- "Knight x Priest, locked, 5 pieces of stock" names the gate and
-- says nothing about why anyone would want it. This is the why. Sits beside Class.displayName as
-- the second thing the UI is allowed to ask a discipline about itself.
--
-- ...AND IT GOES THROUGH THE CATALOG, which is the one thing that made it more than a field read.
-- Forty-six of these are the longest authored prose outside the conversations, and they were the only
-- words on the Roll tab and the shop's detail pane that no translator could ever see: `extract-strings`
-- walks data/conversations/ and nowhere else, so a blueprint string is never stamped, never mirrored
-- into the grid, and nothing reports that it was not (docs/localization.md names this gap). The English
-- stays authored inline on the blueprint and stays authoritative -- Locale.get returns the fallback
-- untouched in the source language -- so this is a seam, not a second place to edit the words.
--
-- Keyed on the class id rather than on anything about the sentence, so rewriting a blurb keeps its row
-- and its translations: the same stable-id promise a conversation's `tag` makes.
function Class.description(id)
    local def = id and Class.defs[id]
    local english = def and def.description
    if not english then return nil end
    return Locale.get(Locale.key.desc(id), english)
end

-- The growth paths a use of `item` should tally toward (models/growth.lua, which reads these as keys
-- into data/growth/<id>.lua). EVERY CLASS IS ITS OWN GROWTH PATH: a build leaning on Ninja stock grows
-- on data/growth/ninja.lua -- a blend the two parent tables cannot express, and the mechanical half of
-- "each class is its own thing." Empty only for an item with no class at all.
--
-- THE FUNCTION IS A LINE LONG NOW, and that is the fold arriving where it was always headed. It used to
-- prefer a `discipline` field and fall back to `class`, which is the two-field world's way of saying
-- "the most specific claim wins"; with one field there is no claim to choose between, and no way to
-- pick the wrong one. It supersedes an older rule still worth knowing about -- "a discipline item
-- tallies BOTH parent classes" -- which existed only because a discipline had no table of its own to
-- tally. There is one file per class now (46 of them), enforced by tests/class_ladder_spec.lua.
--
-- Named `growthClasses` (not `growthPaths`) because the caller and the growth model think in one
-- vocabulary of tally keys, which is exactly what the taxonomy is now.
function Class.growthClasses(item)
    if item and item.class then return { item.class } end
    return {}
end

-- Every subclass (arity-1 class) earned from `class` -- the single-parent cuts of one house.
function Class.subclassesOf(class)
    local out = {}
    for id, def in pairs(Class.defs) do
        if (def.requires or {})[class] ~= nil and Class.arity(id) == 1 then
            out[#out + 1] = id
        end
    end
    table.sort(out) -- `pairs` over defs promises no order, and callers read this as a list
    return out
end

-- ---------------------------------------------------------------------------
-- The class level: how far one BODY has got in one class
-- ---------------------------------------------------------------------------
--
-- FFT's job level, and it is read off cumulative technique EARNED -- `char.technique[key]`, banked two
-- an action by Combat.awardTechnique against the class of the thing in the hand.
--
-- EARNED, NEVER AVAILABLE, and that is the whole reason the ledger is kept in two tables. The Forge
-- bills `technique - techniqueSpent` (Character.techniqueAvailable); this reads the career figure,
-- which only ever rises. A class level that fell when you forged something would make paying for gear
-- cost progression, which is the same mistake Character.recordTechnique already refuses to make.
--
-- IT USED TO BE char.growthBy -- fractional levels apportioned by share of play, written by
-- Growth.resolve. That ledger is gone with the blend that wrote it (models/growth.lua). Two ledgers
-- measuring "how committed is this body to this house" could disagree, and one of them was already
-- being collapsed to a max across the roster by its only reader.
-- FIFTEEN, AND IT IS THE FLOOR COUNT. It was eight, and eight was a number the ladder carried over
-- from an eight-floor descent -- which is a stack this mode has not had since the circle became a
-- stratum (Descent.FLOORS_PER_CIRCLE). Nothing re-cut it when the stack went back to fifteen, and what
-- that cost is the thing this constant is now sized against.
--
-- THE LADDER IS THE SHELF'S ONLY GATE. `Quest.shelfRung` reads the roster's best holder and hands it
-- to Vendor.stock, so a rung is not a title -- it is how much of the catalogue the player can buy.
-- Eight rungs over a 342-row shelf is 42 rows a rung, arriving in eight lumps; fifteen is twenty rows
-- a rung, arriving fifteen times. Same catalogue, half the step, nearly twice the beats.
--
-- AND IT MAKES THE UNIT TRUE. tools/drop_tier.lua spreads every find across 1..CLASS_LEVEL_CAP and
-- says out loud why it reads this rather than typing a number -- "so that 'how deep am I' and 'how far
-- into a class am I' are quoted in one unit". At eight against fifteen floors that sentence was simply
-- false: Spoils.rankBand had to squeeze fifteen floors through eight ranks, so two floors shared a rank
-- most of the way down and the rift could not tell floor six from floor seven. One rung per floor is
-- what the sentence was always claiming, and every ladder derived off this one -- the drop band, the
-- forge ceiling, the market's rotation, the salvage span -- restretches to it without being touched.
Class.CLASS_LEVEL_CAP = 15

-- THE STEP OF THE LADDER: reaching level N costs STEP * N in career technique. A FLOOR AND A QUARTER
-- OF COMMITTED PLAY PER RUNG -- a floor is what it is MEASURED against, and the quarter on top is
-- what being able to walk the floor again costs. Both halves are below, in that order.
--
-- ANCHORED ON A FLOOR rather than on a run, and BOTH HALVES OF THE MEASUREMENT ARE MEASURED.
--
--   WHAT A FIGHT PAYS: 3.97, TO ONE BODY OF FOUR. Measured through models/autobattle -- the real
--   combat model, the same instrument tests/skirmish_spec times fights with -- against a fresh
--   company each fight, reading what one body banked into its best house. EVERY KIND OF FIGHT A
--   FLOOR FIELDS, not just the road pool:
--
--     road, ordinary    3.58   19.6 turns   2.16 actions a body   -17% health   0.33 down
--     road, elite       5.64   32.0 turns   3.47 actions a body   -29% health   0.52 down
--     stair, lieutenant 4.82   24.1 turns   2.89 actions a body   -17% health   0.00 down
--     stair, general    7.00   51.8 turns   4.22 actions a body   -65% health   2.13 down
--
--   A chaff-only sample would have been the wrong instrument and the general's stair is why: it is a
--   fight twice the length of a road stop that takes two of the four bodies down. It is also one of
--   ten, which is the other half of the answer -- eight prowl fights, one elite and one end blend to
--   3.97, within a rounding of the road pool's own 3.58. The mix matters less than it looks; what it
--   buys is knowing that rather than assuming it. Nothing came near TECHNIQUE_PER_BATTLE.
--
--   AND THE AWARD IS LEVEL-SCALED, which is the confound that has to be held still or the number is a
--   fact about the harness's company instead of about the game. Combat.scaledAward runs every bank
--   through Experience.rewardScale, so a company over its ground earns 0.65 a level past the grace.
--   The descent's own equilibrium is +1 -- simulated through Growth.combatantLevel down all fifteen
--   floors, the loop tests/reward_scale_spec walks -- and +1 sits inside REWARD_GRACE, so the figures
--   above are at full pay and that is the right reading. It is a steep lever, steeper than the fight
--   mix: at +2 the same floor pays 21.6 rather than 39.7. Re-measure this if either ladder moves.
--
--   AND 2.14 ACTIONS A BODY IS THE WHOLE OF IT, which is the reading to distrust first and the one
--   that held. Counted at the call rather than inferred from the total: a 4-versus-4 road fight runs
--   19.6 unit-turns -- two and a half rounds, inside tests/skirmish_spec's 22-turn budget -- and the
--   party gets 8.6 actions across four bodies. EVERY ONE OF THEM BANKS (an item with no `class` would
--   bank nothing; none came up), and 88% of the party's turns produce one, so the AI is not wasting
--   them and a human could not find many more. It is not a walkover either: the company loses 17% of
--   its health and puts a body down in a third of fights. The fight is simply SHORT, which is what
--   Arena.SKIRMISH_CAP is for, and two actions a body is what short buys.
--
--   WHAT A FLOOR COSTS: ten fights. The prowl deals a fight per Descent.PROWL_STEPS of WALKING, so a
--   floor's fight count is a property of how far the company walks and nothing declares it. Measured
--   by greedy nearest-unvisited tours of every content cell on real rolled floors: 78 steps on floor
--   one rising to 90 at the bottom, which is 4.9 to 5.6 prowl fights plus the two the board seats
--   (1.98, `. board-report 40 descent`) -- and ten is that route with the BACKTRACKING in it. A
--   greedy tour is the cheapest way to touch everything and no one walks it: a real floor is
--   re-trodden for a cache that needed a key, walked back to the stair, and crossed again to reach a
--   deeper one. Pricing a rung at the optimum would charge for a floor nobody walks.
--
--   AND THE TEN ARE NOT ALL ORDINARY, which is the mix the blend above is taken over. A descent floor
--   deals the ordinary fight on the WALK (`wanderingCombat`), so what it SEATS is the elites and the
--   ends -- 0.97 and 1.00 a floor, `. board-report 40 descent`. Eight, one and one.
--
-- SO A FLOOR PAYS 39.7 -- ten fights at 3.97 -- AND A RUNG COSTS FIFTY. The gap between those two
-- numbers is the only part of this constant that is a judgement rather than a reading, and it is the
-- one worth arguing for.
--
-- A FLOOR IS REPEATABLE, WHICH IS THE WHOLE REASON. This mode is a PLACE (docs/overworld.md): the
-- ground is dealt from the save's seed and the depth, the boards a company has walked are kept whole
-- on the player, the monsters re-arm and the places do not (Descent.rearmFloor), and a company
-- re-enters at the deepest floor it has mapped. So floor three is available for the rest of the
-- playthrough and can be walked as many times as anybody likes. Price a rung at exactly one floor of
-- play and the ladder is not fifteen floors of commitment, it is fifteen laps of whichever floor is
-- cheapest -- and the anchor sentence would be true of a company that never went past the third
-- stair. The extra quarter is what makes the cap something you reach by going DOWN.
--
-- SO MASTERY IS 750 AGAINST THE ~596 A WORKED DESCENT BANKS: a rift cleared end to end gets a body
-- most of the way, and the rest is a second trip or a deeper one. Not a grind wall -- one and a
-- quarter descents, which is inside the loop this mode is built on (a trip is not a run; you come
-- back up to the Ward and the Touchstone and go again). tests/growth_spec.lua pins BOTH ends of that:
-- more than one descent, and less than two.
--
-- IT WAS 120, AND 120 WAS MEASURED ON A PARTY OF ONE. That is the error worth keeping, because the
-- instrument looked right and was pointed at the wrong company: `Player.new()` opens with a roster of
-- just Rowan (data/player.lua's startingRoster), so the harness fought all forty blueprints SOLO and
-- read 11.5 a fight -- and a solo body takes every action its side has. The rift is walked by four
-- (Player.MAX_FIELD). Re-measured at four, the same forty fights bank 3.58 to a body, the party banks
-- MORE in total (17.7 against 12.5), and the fight is over in a third of the turns (19.6 against
-- 60.1): more hands, fewer rounds, a quarter of the fight each. Three times too dear, which put one
-- class at THREE full descents and a 15/15 crossing at five or six -- and the anchor sentence above
-- went on saying one.
--
-- THE CEILING IS 4.31, which is what commitment buys. That is the same body's bank summed across
-- every house rather than its best one, so it is the rate of a body whose every swing is the house it
-- is climbing -- about a fifth faster, capping a little inside the fifteenth floor. And it is close
-- to a hard bound: 19.6 unit-turns over seven bodies is 2.7 turns each, two actions at
-- TECHNIQUE_PER_ACTION. Playing better cannot move this much, which is the property an anchor wants.
--
-- LINEAR, AND THE OLD TRIANGLE IS WHY. This was STEP * N * (N+1) / 2, anchored on the same committed
-- descent and correct AT THE BOTTOM -- rung 8 landed at 828 against ~840 banked. What a triangle does
-- is front-load, and measured against the shelf it front-loads catastrophically: rung 1 cost 23, which
-- is 1.9 fights, so the first 42 rows opened a third of the way through floor ONE, rung 2 landed on the
-- floor-one stair and the ladder was MAXED on floor 12 of 15 -- three floors with nothing left to open.
-- Adding rungs makes a triangle worse at that end, not better: at fifteen rungs and the same anchor the
-- step falls to 9 and rung 1 arrives inside the first fight.
--
-- AND LINEAR IS THE ONLY CURVE THAT FITS, which is worth writing down because it is not a preference.
-- Ask for the rungs to be evenly spaced in floors -- rung 1 at one floor's play, rung 15 at fifteen
-- times that -- over the family STEP_A * n + STEP_B * n(n+1)/2: A + B = STEP and 15A + 120B =
-- 15 * STEP solve to B = 0 at any STEP. Any rising toll buys its rise by pulling rung 1 in earlier,
-- which is the front-loading failure above. The scale of the whole ladder is a separate decision from
-- its shape, and it is the one the quarter makes: stretching every rung by the same factor keeps B at
-- zero and moves only how many floors the fifteen add up to.
--
-- WHAT THE TRIANGLE WAS PROTECTING IS NOT LOST. Its argument was that a flat ladder makes the decision
-- to keep committing stop being a decision after the second rung. That argument is about how many
-- decisions there are, and there are fifteen now rather than eight -- the escalation moved out of the
-- per-rung toll and into the rung count. What a body pays to keep climbing is a floor, every time, and
-- a floor is the most expensive unit this mode has.
Class.CLASS_LEVEL_STEP = 50

-- The career technique needed to reach class level `n`. Zero at nought, which is the floor every body
-- starts on and the one Balance reads as the item's authored magnitude.
function Class.classLevelCost(n)
    n = math.max(0, math.min(Class.CLASS_LEVEL_CAP, n or 0))
    return Class.CLASS_LEVEL_STEP * n
end

-- What level `char` holds in class or discipline `key`, 0..CLASS_LEVEL_CAP.
function Class.classLevel(char, key)
    if not (char and key) then return 0 end
    local earned = (char.technique or {})[key] or 0
    local level = 0
    for n = 1, Class.CLASS_LEVEL_CAP do
        if earned >= Class.classLevelCost(n) then level = n else break end
    end
    return level
end

-- How far into the CURRENT rung `char` is, as career technique and the rung's own span --
-- `held, needed, level`. What a progress bar on the character sheet draws, and it reports zero span at
-- the cap rather than a bar that can never fill.
function Class.classProgress(char, key)
    local level = Class.classLevel(char, key)
    if level >= Class.CLASS_LEVEL_CAP then return 0, 0, level end
    local base = Class.classLevelCost(level)
    local earned = (char and char.technique or {})[key] or 0
    return earned - base, Class.classLevelCost(level + 1) - base, level
end

-- The highest level any body in the roster holds in `key`. The COMPANY-facing reading, for the handful
-- of questions that are genuinely about the company rather than about a body -- a shop's shelf, the
-- forge's ceiling. Max rather than sum, for the reason it always was: specializing one character is
-- what opens the deep end, and spreading the same tally over four bodies does not.
function Class.rosterLevel(player, key)
    local best = 0
    for _, char in ipairs((player and player.roster) or {}) do
        local n = Class.classLevel(char, key)
        if n > best then best = n end
    end
    return best
end

-- Is class `id` unlocked for `char`? Every class named in `requires` is held at that level or above BY
-- THIS BODY, AND -- if it is a crossing -- this body already holds a subclass of EACH parent.
--
-- A ROOT PASSES BOTH TESTS TRIVIALLY, which is not an accident and is not a special case: it has no
-- `requires`, so the first loop runs zero times, and no parents, so the second does not run at all. A
-- root being held from the first morning falls out of the same two rules that gate everything else,
-- which is exactly what folding the seven into this table was for (docs/class-fold.md).
--
-- THE SECOND RULE IS THE STRICTER HALF AND IT SURVIVED THE COLLAPSE DELIBERATELY. `requires` now names
-- both roots of a crossing at a level apiece, and stopping there would have made all twenty-one
-- easier: two class levels is a thing you can drift into, where "hold a subclass of each parent" is a
-- commitment you had to choose twice. See tests/class_ladder_spec's crossing case.
--
-- PER BODY, WHICH IS THE WHOLE OF THE CHANGE. This used to read `player.completedQuests` against a
-- discipline's `requiredQuests`, so a discipline unlocked for the company the moment anyone anywhere
-- had run the quest behind it, and every body in the roster was interchangeable at a given moment. The
-- FFT rule is per unit -- Knight 3 and Monk 3 open Ninja for THAT unit -- and it is what makes the
-- roster diverge instead of levelling in lockstep.
--
-- Recursion is shallow and terminating: a subclass has no discipline prerequisites of its own.
--
-- Tolerates being handed a PLAYER for the transition, since several company-facing callers still ask
-- this question of the whole roster (Class.unlockedSet). A player answers yes when any one of its
-- bodies does, which is the same reading those callers had before.
function Class.isUnlocked(who, id)
    local def = id and Class.defs[id]
    if not def then return false end

    if who and who.roster then
        for _, char in ipairs(who.roster) do
            if Class.isUnlocked(char, id) then return true end
        end
        return false
    end

    for key, need in pairs(def.requires or {}) do
        if Class.classLevel(who, key) < need then return false end
    end

    if Class.arity(id) >= 2 then
        for _, parent in ipairs(Class.parents(id)) do
            local held = false
            for _, subId in ipairs(Class.subclassesOf(parent)) do
                if Class.isUnlocked(who, subId) then held = true; break end
            end
            if not held then return false end
        end
    end

    return true
end

-- Which of `id`'s parent classes the player does NOT yet hold a subclass in -- the list of things
-- standing between them and this discipline, as class ids. Empty when every parent is satisfied
-- (including for a subclass, which has no parent requirement of its own).
--
-- This is the half of Class.isUnlocked that the UI needs and could not previously ask for: that
-- function answers "may I?", which makes a locked row a WALL. Naming the missing parent turns it into
-- a direction, and because a class maps to the house that sells it (Vendor.forClass), the direction is
-- a building in the town the player can walk to. See ui/panels/shop.lua's lockReason.
function Class.missingParents(player, id)
    local def = id and Class.defs[id]
    if not def or Class.arity(id) < 2 then return {} end

    local missing = {}
    for _, parent in ipairs(Class.parents(id)) do
        local held = false
        for _, subId in ipairs(Class.subclassesOf(parent)) do
            if Class.isUnlocked(player, subId) then held = true; break end
        end
        if not held then missing[#missing + 1] = parent end
    end
    return missing
end

-- The set { classId = true } of every discipline currently unlocked for `player`. Vendor.stock
-- takes this bare set so that module stays player-free (the same shape as its `rank`/`recipes` args).
function Class.unlockedSet(player)
    local set = {}
    for id in pairs(Class.defs) do
        if Class.isUnlocked(player, id) then set[id] = true end
    end
    return set
end

-- How far `player` has actually GROWN into discipline `id`: the count of character levels credited to
-- it, read as the MAX across the roster rather than a sum. Specializing one character is what opens
-- the deep end of the ladder (Forge.ceilingFor); spreading the same tally over four bodies does not.
--
-- The data was already being kept and never read back. Class.growthClasses returns the discipline
-- id as a tally key, Character.recordUse accrues it per action, Growth.resolve banks a level against
-- whichever key led at the time into char.growthBy, and models/save.lua persists it. This function is
-- the first reader -- no new bookkeeping, just a question nobody had asked of the ledger yet.
-- FLOORED, because growthBy is booked in shares now (Growth.resolve): a level split 52/48 books 0.52
-- toward one path, so a whole discipline level is a whole level's worth of committed play rather than
-- whatever happened to lead on the day. That is a real tightening of this gate against the old
-- winner-take-all booking, and the honest reading of it.
function Class.level(player, id)
    if not id or not Class.defs[id] then return 0 end
    return Class.rosterLevel(player, id)
end

-- ---------------------------------------------------------------------------
-- What a body IS, and what this company has ever taken up
-- ---------------------------------------------------------------------------

-- THE CLASS THIS BODY IS STANDING IN -- what it was declared as in the Roll, or failing that the class
-- its blueprint was written as -- or NIL when it is neither.
--
-- NO NEUTRAL FALLBACK, and that is the whole reason this is not Growth.classOf. That function answers
-- the same question for the LEVEL-UP table and must always name something, so an undeclared body with
-- no innate class comes back `fighter` (Growth.NEUTRAL_CLASS) -- a default about how to grow, not a
-- statement that the company has a fighter in it. Read as one, it would open the Colosseum on the first
-- morning of every save in the game, on the strength of the recruit who was trained in nothing at all
-- (data/characters/character_avatar.lua). A question about identity gets to answer "none".
function Class.declaredOf(char)
    if not char then return nil end
    local id = char.declaredClass or char.class
    return (id and Class.defs[id]) and id or nil
end

-- HAS THIS COMPANY EVER TAKEN UP `class` -- declared it in the Roll, or hired a body born to it.
--
-- ONE-WAY, AND MARKED AS IT IS READ, which is exactly the shape models/curse.lua's `noticed` has: the
-- live roster is what raises the mark, and the mark is what is answered from then on.
--
-- IT CANNOT READ LIVE, and the reason is a rule one screen away. This is what puts a class's HOUSE on
-- the plaza (models/offer.lua's `declared` gate), and changing class is free and reversible by design
-- (ui/class_editor.lua) -- so a live reading would take the Colosseum off the square the moment a
-- player moved their one fighter across to knight, and the city would become the first thing in this
-- game that shrinks. Every other door gate in the city is monotonic (a trip taken, a wound carried, a
-- find nobody can read); this one is only monotonic because of the ledger, so the ledger is not
-- optional.
--
-- The mark is the CLASS and never the house, because a house shelves several (Vendor.shelves) and the
-- deed the player did was taking up a class.
function Class.markTaken(player, class)
    if not (player and class and Class.defs[class]) then return end
    player.classesTaken = player.classesTaken or {}
    player.classesTaken[class] = true
end

-- Raise the mark for everything the roster is standing in right now. Both readers below go through it,
-- so neither can answer off a ledger the other would have updated first.
local function sweepTaken(player)
    for _, char in ipairs((player and player.roster) or {}) do
        Class.markTaken(player, Class.declaredOf(char))
    end
    return (player and player.classesTaken) or {}
end

function Class.taken(player, class)
    if not (player and class) then return false end
    return sweepTaken(player)[class] == true
end

-- The set of every class this company has ever stood in, for a caller that has to ask about all of them
-- at once -- a house, which shelves a root and every cut of it (models/offer.lua).
function Class.takenSet(player)
    if not player then return {} end
    local set = {}
    for id, held in pairs(sweepTaken(player)) do
        if held then set[id] = true end
    end
    return set
end

-- ---------------------------------------------------------------------------
-- Technique: the earmarked currency a discipline is forged with
-- ---------------------------------------------------------------------------

-- Technique is what a character banks by ACTUALLY PLAYING a discipline, and what the Forge bills
-- instead of gold when the thing on the bench belongs to one (models/forge.lua). It is the FFT JP
-- borrowing, adapted: JP cannot be spent on abilities here, because an ability is a transferable item
-- in a grid and per-character ability learning would break "anyone can carry anything"
-- (models/item.lua). So it buys the RUNG instead of the ability -- play the ninja, the ninja kit gets
-- better -- which is the same loop reaching the same feeling through the gear.
--
-- Why not gold: gold is FUNGIBLE. Four hundred coin off a wolf pack and four hundred off a discipline
-- elite are the same four hundred, so every choice the player made earning them flattens into one
-- pool. Technique is earmarked -- ninja technique comes only from ninja play and forges only ninja
-- gear -- so a run spent committing to something accumulates into that thing rather than into a
-- number. That earmarking is the whole reason this is a second currency rather than a discount.
Class.TECHNIQUE_PER_ACTION = 2

-- WHAT THE CLASS A BODY IS STANDING IN TAKES OUT OF EVERY ACTION, whatever its hands are holding.
--
-- FFT'S RULE, and the reason the badge is a decision rather than a label. There, the JP an action earns
-- goes to the job the unit is standing in, and every other unlocked job gets a quarter of it -- so
-- changing job changes where the climb goes, which is the entire weight of that screen. Ours banked
-- purely off the item's own house, which left the declaration reading nothing but a growth table: a
-- second commitment beside the technique ladder, and the free one.
--
-- OUT OF THE SAME AWARD, NEVER ON TOP OF IT. CLASS_LEVEL_STEP above is anchored on a committed descent
-- banking about 596 -- "one class is a descent and a quarter" -- and an additive bonus would
-- pay a body carrying somebody else's gear MORE per action than one carrying its own, which is both
-- backwards and a move on every number that anchor holds. A split conserves it exactly: a body standing
-- in the house it is swinging banks the full 2 into it, precisely as before, and a body swinging
-- somebody else's splits the same 2 between the hands and the badge.
--
-- One, not FFT's quarter, because the award is only 2 and a ladder authored in whole numbers should not
-- start carrying halves. So the cost of not committing is half your climb in the house you are actually
-- using, and the reward for declaring what you are climbing TOWARD is that it climbs off whatever you
-- happen to hold -- which is what makes standing in the far parent of a crossing a real play rather
-- than a slower version of grinding it directly.
Class.TECHNIQUE_DECLARED_SHARE = 1

-- The ceiling on what ONE battle can bank in a single discipline. The anti-grind clause, and the
-- reason this does not reopen the door models/growth.lua deliberately shut ("no way to grind away a
-- bad roll"): a `free` ability does not end the turn, and a fight the player declines to finish is
-- unbounded actions, so without a cap a single won encounter could be milked for a whole ladder.
--
-- SIZED AGAINST THE FIGHT IT IS CAPPING, which is what moved it. This was 60 -- thirty actions of one
-- discipline -- when every fight was a set-piece of nine bodies running twenty-odd unit-turns. An
-- ordinary stop is now a skirmish (Arena.SKIRMISH_CAP), measured at around twelve unit-turns end to
-- end, of which the player's side takes half; committing every one of those to a single house banks
-- about twelve. A cap of 60 sits five times past that, which is not a bound on anything -- it is a
-- wide, quiet band in which refusing to finish a skirmish pays better than fighting it.
--
-- Fifteen actions of one house still comfortably clears an honestly played set-piece and leaves the
-- milked fight nothing to milk. The cap has never been a target to play toward; it is the line past
-- which the commitment has been demonstrated and the rest is farming.
Class.TECHNIQUE_PER_BATTLE = 30

-- What a rung costs in technique. Climbs with the target level exactly as the gold track it replaces
-- did (Forge.GOLD_PER_LEVEL), so the shape of the ladder is unchanged and only the currency moved.
Class.TECHNIQUE_PER_LEVEL = 10

function Class.techniqueCost(target)
    return Class.TECHNIQUE_PER_LEVEL * math.max(1, target or 1)
end

-- The roster member with the most SPENDABLE technique in `id`, as `char, amount` -- earned minus what
-- the Forge has already billed them (Character.techniqueAvailable). Nil + 0 when nobody has any.
--
-- Spending is tracked in its own table rather than decremented off the earned figure, because that
-- figure is now also the career title and the level-up reading (Character.recordTechnique): billing a
-- forge against it would quietly un-grow the character who paid.
--
-- THE BILL IS PAID BY THE STRONGEST rather than by the carrier or by a shared pot, and each
-- alternative was rejected for a reason worth keeping:
--
--   a shared pot     spreading one cheap discipline item over four bodies would out-earn committing
--                    one, so the dominant play would be for nobody to specialize.
--   the carrier      the tightest loop ("this is her knife"), but gear demonstrably circulates here --
--                    there is a stash, a loadout panel, and selling a unit returns its gear -- and it
--                    would leave a fresh recruit unable to forge anything they picked up.
--
-- Ties settle by roster order, which is stable within a save.
function Class.techniqueHolder(player, id)
    if not id then return nil, 0 end
    local best, bestAmount = nil, 0
    for _, char in ipairs((player and player.roster) or {}) do
        local held = Character.techniqueAvailable(char, id)
        if held > bestAmount then best, bestAmount = char, held end
    end
    return best, bestAmount
end

-- How much technique in `id` this player can actually bring to a bill: the strongest holder's bank.
function Class.technique(player, id)
    local _, amount = Class.techniqueHolder(player, id)
    return amount
end

-- Spend `amount` of `id`'s technique off the strongest holder. All of it comes off ONE body -- the
-- same body the ceiling test above named -- so a bill can never be met by pooling scraps from four
-- characters who each fell short. Returns the character it was billed to, or nil when it could not be
-- paid (the caller checks affordability first; this stays honest if it does not).
--
-- Recorded as SPENDING rather than as a decrement: `char.technique` is the career ledger the title and
-- the level-up both read, so a forge that subtracted from it would make paying for gear cost growth.
function Class.spendTechnique(player, id, amount)
    amount = amount or 0
    if amount <= 0 then return nil end
    local char, held = Class.techniqueHolder(player, id)
    if not char or held < amount then return nil end
    char.techniqueSpent = char.techniqueSpent or {}
    char.techniqueSpent[id] = (char.techniqueSpent[id] or 0) + amount
    return char
end

-- The map { classId = level } across every known discipline. The bare-table companion to
-- unlockedSet, for the same reason: Vendor.stock gates the deep cut on discipline level and must not
-- learn what a player is.
function Class.levelSet(player)
    local set = {}
    for id in pairs(Class.defs) do
        set[id] = Class.level(player, id)
    end
    return set
end

-- The disciplines a vendor of `class` should ANNOUNCE to `player`: unlocked, not yet announced, and
-- carrying `class` as one of their parents (so their stock lands on this shelf). Sorted for a stable
-- order when several came due at once. This is the shop-open hook in states/hub.lua -- it names the
-- newly earned disciplines whose gear just appeared on the rack the player is standing at.
--
-- A multiclass has two parents; it will match at either vendor, but `hasAnnouncedDiscipline` is keyed
-- per discipline, so the first shop opened claims it and the second does not repeat.
function Class.pendingAnnouncements(player, class)
    local Player = require("models.player")
    local out = {}
    for id, def in pairs(Class.defs) do
        local onThisShelf = false
        for _, parent in ipairs(Class.parents(id)) do
            if parent == class then onThisShelf = true end
        end
        if onThisShelf and Class.isUnlocked(player, id)
            and not Player.hasAnnouncedDiscipline(player, id) then
            out[#out + 1] = id
        end
    end
    table.sort(out)
    return out
end

return Class
