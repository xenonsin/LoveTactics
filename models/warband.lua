-- WARBAND: an enemy company drawn as a COMBO rather than as a roster.
--
-- The descent's ordinary fighting was four blueprints -- boar, wolf, stag, ogre -- on all fifteen
-- floors, and every one of them was N copies of a single id. Meanwhile 84 finished, kitted, fightable
-- humanoid bodies sat behind an encounter table with four rows in it, 79 of them discipline exemplars
-- authored expressly to be fought and reachable only from hand-written campaign quests.
--
-- So this composes one out of role buckets instead of listing one. Four slots:
--
--   setup       lands a condition and is individually weak (a poisoner's Envenom -> Poison)
--   payoff      reads that condition and is paid enormously for it (Detonate, doubled in a blast)
--   multiplier  hits nothing; makes the other two arrive sooner or live longer (a Rally Banner)
--   anchor      the body that walks at you while the other three work
--
-- 23 anchors x 16 blades x 23 reach x 17 support is 143,888 distinct companies, which is the easy part.
-- The design is in refusing to draw uniformly from it, because most of those are four bodies with
-- nothing to say to each other.
--
-- THE DRAW IS SEEDED BY THE SETUP. Pick the setup first, then draw its payoff only from bodies that
-- actually read the condition it lands: a poisoner pulls a mage who can set the Poison off, an
-- inquisitor's Mark pulls an assassin, a Shieldbreak pulls anything that hits once and hard. Every
-- company that arrives is a sentence.
--
-- ...FOUR TIMES IN FIVE. See COMBO_RATE.
--
-- REQUIRES NOTHING, AND MUST STAY THAT WAY. data/encounters/*.lua load this at file scope, and
-- models/encounter.lua -> models/registry.lua -> each blueprint, so requiring anything from models/
-- here would close a cycle. Same rule models/curve.lua states and for the same reason. Everything below
-- is id lists and integer arithmetic.

local Warband = {}

-- How often the payoff is drawn to MATCH the setup rather than at large. Four in five.
--
-- Not 1.0, and the missing fifth is the whole reason this is a constant rather than an `if`. At a full
-- rate the setup body becomes a promise: see a poisoner, know exactly what the other three are. At 0.8
-- it stays a strong inference the player is usually right about and occasionally is not, which is the
-- difference between reading a fight and reciting one.
Warband.COMBO_RATE = 4 -- ...in COMBO_SCALE
Warband.COMBO_SCALE = 5

-- ---------------------------------------------------------------------------
-- The buckets
-- ---------------------------------------------------------------------------

-- SETUPS, each tagged with the condition it puts on the board. The tag is the join key -- it is what
-- PAYOFFS below is indexed by -- so a body is listed here for what its signature LEAVES BEHIND, never
-- for how hard it hits.
-- THE ROOT CLASSES ARE IN HERE NOW, AND THAT IS NOT DECORATION. Every body below this line is a
-- DISCIPLINE, and a discipline asks for a rung (Class.gateLevel) -- the cheapest is 3. So once the draw
-- reads that gate (Warband.legal), floors one and two could field four bodies between them, three of
-- them anchors: no setup, no multiplier, and the combo machine with nothing to work with on the two
-- boards it matters most. The seven roots ask for nothing and were simply never listed.
Warband.SETUPS = {
    { id = "character_rogue",        condition = "coin" },       -- Pickpocket, at rung 0
    { id = "character_alchemist",    condition = "poison" },     -- a coating, at rung 0
    { id = "character_poisoner",     condition = "poison" },     -- Envenom: coatings that rot on
    { id = "character_plague_knight", condition = "poison" },    -- Contagion: the same, spread by contact
    { id = "character_inquisitor",   condition = "mark" },       -- Mark of Heresy: names one of yours
    { id = "character_poacher",      condition = "root" },       -- Bolas: it is not going anywhere
    { id = "character_champion",     condition = "pull" },       -- Provoke: decides where the fight is
    { id = "character_bulwark",      condition = "pull" },       -- Push: decides it the other way
    { id = "character_vanguard",     condition = "guardbreak" }, -- Shieldbreak: the armour stops mattering
    { id = "character_spellbreaker", condition = "manaburn" },   -- Mana Sunder: the answer stops existing
    { id = "character_saboteur",     condition = "ground" },     -- Set Charge: the route costs something
    { id = "character_bombardier",   condition = "ground" },     -- Blast Charge: the same, thrown
    { id = "character_thief",        condition = "coin" },       -- Pickpocket: your purse is the resource
    { id = "character_bandit_chief", condition = "coin" },       -- Shakedown: the same, with menace
}

-- PAYOFFS, indexed by the condition they are paid for. A body may appear under several: a barbarian's
-- Fury is worth having against anything that cannot walk away, however it came to be stuck.
Warband.PAYOFFS = {
    poison     = { "character_mage", "character_battlemage", "character_necromancer", "character_elementalist", "character_battlemage" },
    mark       = { "character_assassin", "character_poacher", "character_duelist" },
    root       = { "character_fighter", "character_barbarian", "character_monk", "character_duelist", "character_crusader" },
    pull       = { "character_fighter", "character_barbarian", "character_monk", "character_crusader" },
    guardbreak = { "character_barbarian", "character_assassin", "character_warbrewer" },
    manaburn   = { "character_battlemage", "character_battlemage", "character_summoner" },
    ground     = { "character_archer", "character_poacher", "character_trapper_ambusher" },
    coin       = { "character_rogue", "character_mammonite", "character_mammonite" },
}

-- The loose pool, for the fifth company that is a coincidence rather than a sentence. Every payoff
-- above, flattened once at load rather than per draw.
Warband.ANY_PAYOFF = (function()
    local seen, out = {}, {}
    -- Sorted keys: this builds a list whose ORDER decides which body a hash lands on, and pairs() order
    -- holds still within one build and is promised by nothing across two. An unsorted flatten is a
    -- different company on another machine, for the same seed.
    local keys = {}
    for condition in pairs(Warband.PAYOFFS) do keys[#keys + 1] = condition end
    table.sort(keys)
    for _, condition in ipairs(keys) do
        for _, id in ipairs(Warband.PAYOFFS[condition]) do
            if not seen[id] then seen[id] = true; out[#out + 1] = id end
        end
    end
    return out
end)()

-- MULTIPLIERS: the body that hits nothing and is killed first by anyone paying attention.
Warband.MULTIPLIERS = {
    "character_priest",   -- the root: a heal, at rung 0, so a shallow company has one
    "character_warlord",  -- Rally Banner: the whole line, a turn early
    "character_paladin",  -- Lay on Hands: the setup survives to land twice
    "character_sentinel", -- Shared Burden: the fragile body stops being fragile
    "character_warden",   -- Warding Line: the flank you were going to use
    "character_totemist", -- Raise Totem: ground that is worth more to them than to you
    "character_shaman",   -- Call Spirit: another body, from nowhere
    "character_apothecary", "character_inquisitor", "character_exorcist", "character_totemist",
}

-- ANCHORS: the front rank. Repeated to fill out the head-count, so this list is the one place a
-- company's bulk comes from.
Warband.ANCHORS = {
    "character_knight", "character_crusader", "character_forsworn_knight", "character_bulwark",
    "character_vanguard", "character_champion", "character_bulwark", "character_vanguard", "character_sentinel",
    "character_spellbreaker", "character_paladin", "character_warden", "character_warlord", "character_duelist",
    "character_barbarian", "character_fighter",
}

-- ---------------------------------------------------------------------------
-- The draw
-- ---------------------------------------------------------------------------

-- A plain integer hash, for the reason models/descent.lua's is one: a run is a seed and a depth, a
-- resume re-derives everything from them, and a stateful RNG would both perturb whatever else drew this
-- frame and be perturbed BY it. Pure in, pure out, identical on every machine.
--
-- Bit ops are avoided on purpose -- this is Lua 5.1 and it has none. Multiply-and-mod over values that
-- stay well inside a double's exact-integer range does the same job.
local function hash(seed, salt)
    local h = ((seed or 0) % 1000003) * 31 + (salt or 0) * 104729
    h = (h * 1103515245 + 12345) % 2147483648
    return h
end

-- `exclude` walks forward from the hashed index rather than rejecting and re-rolling, so a list whose
-- only entry IS the excluded body returns nil instead of looping, and every other case lands on a real
-- neighbour in one pass. Deterministic either way.
local function pick(list, seed, salt, exclude)
    local n = #list
    if n == 0 then return nil end
    local start = hash(seed, salt) % n
    for i = 0, n - 1 do
        local candidate = list[((start + i) % n) + 1]
        if candidate ~= exclude then return candidate end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- WHAT THIS FLOOR COULD PLAUSIBLY HAVE PRODUCED
-- ---------------------------------------------------------------------------

-- A company is the one thing that appears on every floor, so what it is MADE of has to be what the
-- depth can account for. Drawn flat, a level-four pair on the first board of the game meets an
-- assassin, a necromancer or a warden -- bodies whose disciplines a player cannot reach for another
-- five, nine and fifteen rungs.
--
-- THE GATE ALREADY EXISTED AND WAS ALREADY TRUSTED. Class.gateLevel answers the rung a discipline asks
-- for, on the same 0..CLASS_LEVEL_CAP ladder the floor count runs on, and the drop pool has read it
-- since a Warden charm fell out of floor one eight rungs early (Spoils.depthOf). This is that reading,
-- one system over.
--
-- REQUIRES NOTHING AT MODULE SCOPE, which is the constraint this whole file is written under (see its
-- header): data/encounters/*.lua load it at file scope, so models/class.lua and models/character.lua
-- are pulled in lazily, inside the call.
--
-- A NIL FLOOR ADMITS EVERYTHING. Muster rates compositions long before a board exists and the campaign
-- has no depth at all, so a caller that cannot say how deep it is gets the full roster rather than the
-- opening floor's four -- a rating is not a placement.
function Warband.legal(id, floor)
    if not floor then return true end
    local Class = require("models.class")
    local Character = require("models.character")
    local def = Character.defs[id]
    -- The blueprint's `class` is its ROOT and answers 0 for everything; `discipline` is the thing that
    -- asks for a rung. Reading the root here would gate nothing and look like it gated everything.
    local key = def and (def.discipline or def.class)
    return Class.gateLevel(key) <= floor
end

-- The same list, filtered. Returns the original when nothing is admitted, so a bucket that the gate
-- empties cannot produce a nil body -- a company three roles short is worse than one body too deep.
local function legalIn(list, floor)
    if not floor then return list end
    local out = {}
    for _, id in ipairs(list) do
        if Warband.legal(id, floor) then out[#out + 1] = id end
    end
    return #out > 0 and out or list
end

-- The number this company is drawn from. A DESCENT hands over its run seed, so the same floor of the
-- same run always meets the same company across a save and reload; a campaign board has no seed of its
-- own and falls back to the day, which is the only clock it keeps.
--
-- Read defensively: `quest` is nil for a caller with no board under it (models/muster.lua rates
-- compositions long before a fight exists), and a nil seed must not become a nil company.
function Warband.seedFor(ctx)
    ctx = ctx or {}
    local quest = ctx.quest
    local run = quest and quest.descent
    local base = (run and run.seed) or 0
    local floor = (run and run.floor) or 0
    return base + floor * 7919 + (ctx.day or 1) * 31
end

-- How many bodies this company brings. The four roles always, plus anchors on top -- and the roles are
-- listed FIRST, because Arena.clampComposition keeps one of every distinct id before any repeated
-- filler. So a company clamped to Arena.SKIRMISH_CAP on thin ground loses its crowd and keeps its combo,
-- which is the whole reason the order matters.
local function anchorCount(day)
    return math.max(0, math.min(3, math.floor((day or 1) / 10)))
end

-- How deep this company is standing, or nil where the caller cannot say. Read off the descent's run
-- rather than off the day, because the rung ladder and the floor count are the same ladder.
local function floorOf(ctx)
    local quest = ctx and ctx.quest
    local run = quest and quest.descent
    return run and run.floor or nil
end

-- Compose one company. Returns a list of character ids, roles first.
function Warband.compose(ctx)
    ctx = ctx or {}
    local seed = Warband.seedFor(ctx)
    local floor = floorOf(ctx)

    -- The setup is filtered as a list of entries rather than of ids, because it carries the condition
    -- the payoff is drawn against -- losing it would break the combo rather than narrow it.
    local setups = {}
    for _, entry in ipairs(Warband.SETUPS) do
        if Warband.legal(entry.id, floor) then setups[#setups + 1] = entry end
    end
    if #setups == 0 then setups = Warband.SETUPS end
    local setup = setups[(hash(seed, 1) % #setups) + 1]

    -- The combo roll. Four in five draw the payoff from the setup's own condition; the fifth draws at
    -- large, so reading the setup body is an inference rather than a guarantee.
    local combo = (hash(seed, 2) % Warband.COMBO_SCALE) < Warband.COMBO_RATE
    -- The setup is EXCLUDED from its own payoff draw rather than dropped afterwards. Several bodies sit
    -- on both sides -- a poacher sets the ground it then shoots over -- and dropping the collision left
    -- a company with a setup, no payoff, and nothing for the combo to be about. Redrawn, it keeps four
    -- roles in every case.
    local payoff = combo
        and pick(legalIn(Warband.PAYOFFS[setup.condition] or Warband.ANY_PAYOFF, floor), seed, 3, setup.id)
        or pick(legalIn(Warband.ANY_PAYOFF, floor), seed, 3, setup.id)
    -- A condition whose whole payoff list is the setup itself falls back to the open pool, so no
    -- authoring accident can produce a three-body company.
    payoff = payoff or pick(legalIn(Warband.ANY_PAYOFF, floor), seed, 6, setup.id)

    local list = { setup.id }
    if payoff then list[#list + 1] = payoff end
    local mult = pick(legalIn(Warband.MULTIPLIERS, floor), seed, 4)
    if mult then list[#list + 1] = mult end

    local anchor = pick(legalIn(Warband.ANCHORS, floor), seed, 5)
    if anchor then
        for _ = 1, 1 + anchorCount(ctx.day) do list[#list + 1] = anchor end
    end
    return list
end

return Warband
