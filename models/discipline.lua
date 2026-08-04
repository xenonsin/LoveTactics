-- Discipline logic. Blueprints live in data/disciplines/<id>.lua (see docs/classes.md, "Disciplines",
-- and the authoring slate in docs/disciplines-plan.md).
--
-- A discipline is a shop taxonomy like `class`: unlocking it adds a locked deeper cut of items to its
-- parent vendor shelf(es). Arity is the whole distinction -- one parent is a subclass, two is a
-- multiclass -- and the gate is earned advancement: a multiclass unlocks only once the player already
-- holds a subclass of EACH parent (which is what opens its capstone quest).
--
-- Pure logic (no love.graphics), so it loads under the headless tests.

local Registry = require("models.registry")

local Discipline = {}

Discipline.defs = Registry.load("data/disciplines", "data.disciplines")

-- The parent classes of a discipline id (its `classes` list). {} for an unknown id.
function Discipline.parents(id)
    local def = id and Discipline.defs[id]
    return (def and def.classes) or {}
end

-- Arity: 1 = subclass, 2 = multiclass, 0 = unknown id.
function Discipline.arity(id)
    return #Discipline.parents(id)
end

-- The display name of discipline `id` ("Ninja"), or nil when the id is absent or unknown. The single
-- place the UI turns a stored id into words, so every surface that names an item's discipline -- the
-- tooltip's row, the shop shelf, the forge -- says it the same way, and a stale id on an item prints
-- nothing rather than leaking a raw slug into the panel.
function Discipline.displayName(id)
    local def = id and Discipline.defs[id]
    if not def then return nil end
    return def.name or id
end

-- The one-or-two sentence blurb a shop shows for discipline `id`: what the path IS, and the mechanic
-- it is built on. Nil for an unknown id, and for a blueprint that has not written one yet.
--
-- Authored on the blueprint rather than derived, and read by ui/panels/shop.lua's section detail. A
-- locked path collapses to its header on the shelf, so the only thing the player can read about it
-- before earning it is that pane -- "Knight x Priest, locked, 5 pieces of stock" names the gate and
-- says nothing about why anyone would want it. This is the why. Sits beside Discipline.displayName as
-- the second thing the UI is allowed to ask a discipline about itself.
function Discipline.description(id)
    local def = id and Discipline.defs[id]
    return def and def.description or nil
end

-- The growth paths a use of `item` should tally toward (models/growth.lua, which reads these as keys
-- into data/growth/<id>.lua). A discipline is ITS OWN growth path: a discipline item tallies the
-- discipline id, so a build leaning on Ninja stock grows on data/growth/ninja.lua -- a blend the two
-- parent tables cannot express, and the mechanical half of "each discipline is its own thing." A plain
-- item tallies its single `class`. Empty for a class-less, discipline-less item (a natural weapon).
--
-- This SUPERSEDES the older "a discipline item tallies both parent classes" rule. It could because
-- every discipline now has a growth table of its own (there is one file per discipline, enforced by
-- tests/discipline_spec.lua); before, a discipline had no table and had to borrow its parents'. The
-- unlock gating means the path is naturally earned -- a character cannot grow toward a discipline
-- until that discipline's stock is on the shelf to carry.
--
-- Named `growthClasses` (not `growthPaths`) because the caller and the growth model still think in
-- one vocabulary of tally keys, and a discipline id is just another key alongside the seven classes.
function Discipline.growthClasses(item)
    if not item then return {} end
    if item.discipline and Discipline.defs[item.discipline] then
        return { item.discipline }
    end
    if item.class then return { item.class } end
    return {}
end

-- Every subclass (arity-1 discipline) whose single parent is `class`.
function Discipline.subclassesOf(class)
    local out = {}
    for id, def in pairs(Discipline.defs) do
        if def.classes and #def.classes == 1 and def.classes[1] == class then
            out[#out + 1] = id
        end
    end
    return out
end

-- Is discipline `id` unlocked for `player`? All its requiredQuests are completed, AND -- if it is a
-- multiclass -- the player already holds at least one unlocked subclass of EACH parent (earned
-- advancement). Recursion is shallow and terminating: a subclass has no discipline prerequisites.
function Discipline.isUnlocked(player, id)
    local def = id and Discipline.defs[id]
    if not def then return false end

    local completed = (player and player.completedQuests) or {}
    for _, q in ipairs(def.requiredQuests or {}) do
        if not completed[q] then return false end
    end

    if #(def.classes or {}) >= 2 then
        for _, parent in ipairs(def.classes) do
            local held = false
            for _, subId in ipairs(Discipline.subclassesOf(parent)) do
                if Discipline.isUnlocked(player, subId) then held = true; break end
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
-- This is the half of Discipline.isUnlocked that the UI needs and could not previously ask for: that
-- function answers "may I?", which makes a locked row a WALL. Naming the missing parent turns it into
-- a direction, and because a class maps to the house that sells it (Vendor.forClass), the direction is
-- a building in the town the player can walk to. See ui/panels/shop.lua's lockReason.
function Discipline.missingParents(player, id)
    local def = id and Discipline.defs[id]
    if not def or #(def.classes or {}) < 2 then return {} end

    local missing = {}
    for _, parent in ipairs(def.classes) do
        local held = false
        for _, subId in ipairs(Discipline.subclassesOf(parent)) do
            if Discipline.isUnlocked(player, subId) then held = true; break end
        end
        if not held then missing[#missing + 1] = parent end
    end
    return missing
end

-- The set { disciplineId = true } of every discipline currently unlocked for `player`. Vendor.stock
-- takes this bare set so that module stays player-free (the same shape as its `rank`/`recipes` args).
function Discipline.unlockedSet(player)
    local set = {}
    for id in pairs(Discipline.defs) do
        if Discipline.isUnlocked(player, id) then set[id] = true end
    end
    return set
end

-- How far `player` has actually GROWN into discipline `id`: the count of character levels credited to
-- it, read as the MAX across the roster rather than a sum. Specializing one character is what opens
-- the deep end of the ladder (Forge.ceilingFor); spreading the same tally over four bodies does not.
--
-- The data was already being kept and never read back. Discipline.growthClasses returns the discipline
-- id as a tally key, Character.recordUse accrues it per action, Growth.resolve banks a level against
-- whichever key led at the time into char.growthBy, and models/save.lua persists it. This function is
-- the first reader -- no new bookkeeping, just a question nobody had asked of the ledger yet.
function Discipline.level(player, id)
    if not id or not Discipline.defs[id] then return 0 end
    local best = 0
    for _, char in ipairs((player and player.roster) or {}) do
        local n = (char.growthBy or {})[id] or 0
        if n > best then best = n end
    end
    return best
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
Discipline.TECHNIQUE_PER_ACTION = 2

-- The ceiling on what ONE battle can bank in a single discipline. The anti-grind clause, and the
-- reason this does not reopen the door models/growth.lua deliberately shut ("no way to grind away a
-- bad roll"): a `free` ability does not end the turn, and a fight the player declines to finish is
-- unbounded actions, so without a cap a single won encounter could be milked for a whole ladder.
-- Thirty actions of one discipline is a thoroughly committed battle and well past the point the
-- reward has been earned; everything after it is farming.
Discipline.TECHNIQUE_PER_BATTLE = 60

-- What a rung costs in technique. Climbs with the target level exactly as the gold track it replaces
-- did (Forge.GOLD_PER_LEVEL), so the shape of the ladder is unchanged and only the currency moved.
Discipline.TECHNIQUE_PER_LEVEL = 10

function Discipline.techniqueCost(target)
    return Discipline.TECHNIQUE_PER_LEVEL * math.max(1, target or 1)
end

-- The roster member holding the most technique in `id`, as `char, amount`. Nil + 0 when nobody has
-- any. THE BILL IS PAID BY THE STRONGEST rather than by the carrier or by a shared pot, and each
-- alternative was rejected for a reason worth keeping:
--
--   a shared pot     spreading one cheap discipline item over four bodies would out-earn committing
--                    one, so the dominant play would be for nobody to specialize.
--   the carrier      the tightest loop ("this is her knife"), but gear demonstrably circulates here --
--                    there is a stash, a loadout panel, and selling a unit returns its gear -- and it
--                    would leave a fresh recruit unable to forge anything they picked up.
--
-- Ties settle by roster order, which is stable within a save.
function Discipline.techniqueHolder(player, id)
    if not id or not Discipline.defs[id] then return nil, 0 end
    local best, bestAmount = nil, 0
    for _, char in ipairs((player and player.roster) or {}) do
        local held = (char.technique or {})[id] or 0
        if held > bestAmount then best, bestAmount = char, held end
    end
    return best, bestAmount
end

-- How much technique in `id` this player can actually bring to a bill: the strongest holder's bank.
function Discipline.technique(player, id)
    local _, amount = Discipline.techniqueHolder(player, id)
    return amount
end

-- Spend `amount` of `id`'s technique off the strongest holder. All of it comes off ONE body -- the
-- same body the ceiling test above named -- so a bill can never be met by pooling scraps from four
-- characters who each fell short. Returns the character it was billed to, or nil when it could not be
-- paid (the caller checks affordability first; this stays honest if it does not).
function Discipline.spendTechnique(player, id, amount)
    amount = amount or 0
    if amount <= 0 then return nil end
    local char, held = Discipline.techniqueHolder(player, id)
    if not char or held < amount then return nil end
    char.technique[id] = held - amount
    return char
end

-- The map { disciplineId = level } across every known discipline. The bare-table companion to
-- unlockedSet, for the same reason: Vendor.stock gates the deep cut on discipline level and must not
-- learn what a player is.
function Discipline.levelSet(player)
    local set = {}
    for id in pairs(Discipline.defs) do
        set[id] = Discipline.level(player, id)
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
function Discipline.pendingAnnouncements(player, class)
    local Player = require("models.player")
    local out = {}
    for id, def in pairs(Discipline.defs) do
        local onThisShelf = false
        for _, parent in ipairs(def.classes or {}) do
            if parent == class then onThisShelf = true end
        end
        if onThisShelf and Discipline.isUnlocked(player, id)
            and not Player.hasAnnouncedDiscipline(player, id) then
            out[#out + 1] = id
        end
    end
    table.sort(out)
    return out
end

return Discipline
