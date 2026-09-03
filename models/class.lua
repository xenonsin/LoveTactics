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
function Class.description(id)
    local def = id and Class.defs[id]
    return def and def.description or nil
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
Class.CLASS_LEVEL_CAP = 8

-- THE STEP OF THE LADDER, which is triangular: reaching level N costs STEP * N * (N+1) / 2 in career
-- technique, so the rungs are 23, 69, 138, 230, 345, 483, 644, 828.
--
-- ANCHORED ON A COMMITTED DESCENT rather than picked. Technique is TECHNIQUE_PER_ACTION = 2 an action,
-- capped at TECHNIQUE_PER_BATTLE = 30 a fight, and a full descent is around seventy fights -- so a body
-- that commits to one house for a whole run banks in the neighbourhood of 840. 23 puts the top rung at
-- 828, one short of overshooting it: MASTERING ONE CLASS IS ONE COMMITTED DESCENT.
--
-- Triangular rather than flat for the reason a number spent many times always is: a flat ladder makes
-- the eighth rung cost exactly what the first did, so the decision to keep committing stops being a
-- decision after the second one.
Class.CLASS_LEVEL_STEP = 23

-- The career technique needed to reach class level `n`. Zero at nought, which is the floor every body
-- starts on and the one Balance reads as the item's authored magnitude.
function Class.classLevelCost(n)
    n = math.max(0, math.min(Class.CLASS_LEVEL_CAP, n or 0))
    return Class.CLASS_LEVEL_STEP * n * (n + 1) / 2
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
-- banking about 840 -- "mastering one class is one committed descent" -- and an additive bonus would
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
