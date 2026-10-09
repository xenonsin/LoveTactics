-- ADVENTURERS: rival parties of people, met on every floor of the rift ("The Rift's Adventurers",
-- approved 2026-10-09 over three review rounds).
--
-- WHY PEOPLE ARE BACK, AND WHAT IS DIFFERENT THIS TIME. Human companies were deleted on 2026-09-22
-- (92ff549d, with models/warband.lua) because a full company of people met by a full company is a
-- mirror match the combat model cannot close: both sides heal, both mitigate, and the Broken Column sat
-- at autobattle's 400-turn cap. These parties come back under the limits that fight did not have: a
-- core of three that grows with depth (never past six), at most one sustain body per three, a body in
-- every party whose kit ends an exchange, and a fight-length budget of their own
-- (tests/adventurers_spec.lua). The author's calls are recorded beside each rule below.
--
-- A PARTY IS WRITTEN IN CLASSES, AND THE RACE IS ROLLED WHEN IT IS FIELDED. "Any race can be any class
-- BUT they can have preferences" (the author, round 1). One race-free body per class lives in
-- data/characters/character_adv_<class>.lua; the fight fields it as `character_adv_<class>@<race>`, and
-- Character.defs resolves that id lazily into a derived blueprint wearing the race (Adventurers.variant).
-- An id is the one thing every path already carries -- the arena, muster, the drop draw, a save, the
-- wiki -- so the race rides in it rather than in a side table four callers would have to thread.
--
-- REQUIRES ONLY models/seed.lua AT FILE SCOPE, and must stay that way:
-- data/encounters/*.lua load this, and models/encounter.lua -> models/registry.lua -> each blueprint,
-- so a models/ require here that reached Item or Character would close a cycle. Class and Race are asked
-- lazily, inside the composition and the variant, which only run once a fight is rated or built.

local Seed = require("models.seed")

local Adventurers = {}

-- The eight peoples a party may be drawn from: the playable races, which are the ones a company can
-- hire, so a party is a company like yours. No creature races and no unplayable humanoid (round 1).
Adventurers.RACES = { "human", "dwarf", "elf", "goblin", "kobold", "naga", "oni", "orc" }

-- WHICH CLASSES EACH RACE LEANS TO (round 2, approved as a table). Every class has at least one leaning
-- race, which tests/adventurers_spec.lua holds. Humans lean widest, as the city's own people.
Adventurers.LEAN = {
    human  = { "knight", "priest", "mage", "exorcist", "crusader", "inquisitor", "paladin", "theurge" },
    dwarf  = { "bulwark", "sentinel", "mammonite", "artificer", "vanguard", "warbrewer" },
    elf    = { "hunter", "mage", "elementalist", "druid", "duelist", "spellbreaker", "theurge" },
    orc    = { "fighter", "barbarian", "warlord", "champion", "necromancer", "totemist", "warden" },
    goblin = { "rogue", "thief", "bombardier", "poisoner", "saboteur" },
    kobold = { "alchemist", "beastmaster", "trapper", "poacher", "skirmisher", "summoner" },
    naga   = { "shaman", "herbalist", "plague_knight", "apothecary" },
    oni    = { "monk", "assassin", "ninja", "battlemage" },
}

-- HALF THE BODIES OF A CLASS COME FROM A RACE THAT LEANS TO IT, the other half from any of the eight
-- (round 2: "most bulwarks are dwarves, but you'll meet a goblin bulwark"). Out of LEAN_SCALE.
Adventurers.LEAN_SHARE = 1
Adventurers.LEAN_SCALE = 2

-- THE RACE ITEMS: one item per race-and-class pairing, sixteen in all (rounds 2 and 3). Each is its
-- OWN item ("these should be separate items and have race restrictions") and carries `race` on its
-- blueprint, which is a HARD equip gate (round 3, option C): no other body may equip it
-- (Character.canCarry). A fielded adventurer of the right race and class carries its pairing's item.
Adventurers.RACE_ITEMS = {
    dwarf  = { bulwark = "utility_mountains_root", mammonite = "utility_hoardkeeper" },
    elf    = { hunter = "utility_flawless_shot", duelist = "utility_perfect_form" },
    orc    = { barbarian = "utility_blood_tally", warlord = "utility_trophy_banner" },
    goblin = { thief = "utility_grudge_purse", saboteur = "utility_never_alone" },
    kobold = { trapper = "utility_many_hands", beastmaster = "utility_dragon_kin" },
    naga   = { plague_knight = "utility_constrict", apothecary = "utility_shed_skin" },
    oni    = { monk = "utility_horned_fist", assassin = "utility_red_mark" },
    human  = { knight = "utility_sworn_shield", alchemist = "utility_well_stocked" },
}

-- The body a class is fielded as.
function Adventurers.bodyOf(class) return "character_adv_" .. class end

-- The class a body id answers to, or nil for anything that is not an adventurer. Takes a variant id too.
function Adventurers.classOf(id)
    if type(id) ~= "string" then return nil end
    return id:match("^character_adv_([%w_]+)@") or id:match("^character_adv_([%w_]+)$")
end

-- `character_adv_bulwark@dwarf` -> "character_adv_bulwark", "dwarf". A plain id comes back with nil.
function Adventurers.split(id)
    if type(id) ~= "string" then return id, nil end
    local base, race = id:match("^(character_adv_[%w_]+)@(%a+)$")
    if base then return base, race end
    return id, nil
end

function Adventurers.variantId(class, race) return Adventurers.bodyOf(class) .. "@" .. race end

-- The races that lean to `class`, in RACES order (so the first is stable).
function Adventurers.leaningRaces(class)
    local out = {}
    for _, race in ipairs(Adventurers.RACES) do
        for _, c in ipairs(Adventurers.LEAN[race]) do
            if c == class then out[#out + 1] = race break end
        end
    end
    return out
end

-- The race item a body of `race` walking `class` carries, or nil.
function Adventurers.raceItemOf(race, class)
    local byClass = Adventurers.RACE_ITEMS[race]
    return byClass and byClass[class] or nil
end

-- ---------------------------------------------------------------------------
-- Size and membership
-- ---------------------------------------------------------------------------

-- HOW MANY A PARTY FIELDS AT A DEPTH (round 1, "it's max a party of 6"): a core of three on the first
-- two floors, then 4, 5 and 6. Never past MAX, which is also every party's own `enemyCap` -- an ordinary
-- fight is otherwise clamped to Arena.SKIRMISH_CAP's four.
Adventurers.MAX = 6
function Adventurers.sizeAt(depth)
    depth = depth or 1
    if depth <= 2 then return 3 end
    if depth <= 5 then return 4 end
    if depth <= 9 then return 5 end
    return 6
end

-- THE FLOOR A CLASS OPENS ON: its own unlock level, since one class level is one floor
-- (Class.CLASS_LEVEL_STEP, docs/shelf.md). A root unlocks at nothing and walks from floor 1.
function Adventurers.floorOf(class)
    local n = require("models.class").gateLevel(class)
    return math.max(1, n)
end

-- The floor a party first appears on: where its highest-gated core class opens (round 1, approved).
function Adventurers.openingFloor(core)
    local n = 1
    for _, c in ipairs(core) do n = math.max(n, Adventurers.floorOf(c)) end
    return n
end

-- WHO STANDS IN A PARTY AT `depth`, as classes: the core, then its growth members in authored order,
-- each one only once its own class is open on this floor, until the party reaches its size. A party
-- never leaves the rift once it has opened (round 2: the ceiling was cut because it took the root
-- shelves off the deep floors); it grows instead.
function Adventurers.members(core, grow, depth)
    local out = {}
    for _, c in ipairs(core) do out[#out + 1] = c end
    local size = Adventurers.sizeAt(depth)
    for _, c in ipairs(grow or {}) do
        if #out >= size then break end
        if Adventurers.floorOf(c) <= (depth or 1) then out[#out + 1] = c end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- The race roll
-- ---------------------------------------------------------------------------

-- THE RACE A BODY IS FIELDED AS. NO SEED, NO ROLL, which is models/band.lua's rule for the same reason:
-- every path that RATES a fight (Muster, Descent.floorPool, the wiki) hands over a seedless ctx and must
-- get one stable answer -- the class's first leaning race. A seeded fight rolls: LEAN_SHARE in
-- LEAN_SCALE from the leaning races, otherwise any of the eight. Keyed on the party and the slot, so two
-- bodies of one class in one party roll apart, and folded with the depth so the same party met on two
-- floors is not the same people twice.
function Adventurers.raceFor(class, ctx, key, slot)
    local leaning = Adventurers.leaningRaces(class)
    local fallback = leaning[1] or "human"
    if not (ctx and ctx.seed) then return fallback end
    local roll = Seed.mix(ctx.seed, Seed.text(key or ""), slot or 0, ctx.depth or 1)
    -- Scaled across the span rather than modded: models/band.lua's header says why the low digits of
    -- Seed.mix are the bad end to read.
    local pick = math.floor(roll * Adventurers.LEAN_SCALE / Seed.SPAN)
    local list = (pick < Adventurers.LEAN_SHARE and #leaning > 0) and leaning or Adventurers.RACES
    local roll2 = Seed.mix(roll, 7919, slot or 0)
    return list[math.floor(roll2 * #list / Seed.SPAN) + 1]
end

-- A PARTY'S COMPOSITION: a function of the fight's ctx, as every banded stop's is. `key` is the
-- encounter's own id, which seeds the race roll.
function Adventurers.compose(key, core, grow)
    return function(ctx)
        ctx = ctx or {}
        local ids = {}
        for i, class in ipairs(Adventurers.members(core, grow, ctx.depth or 1)) do
            ids[#ids + 1] = Adventurers.variantId(class, Adventurers.raceFor(class, ctx, key, i))
        end
        return ids
    end
end

-- A PARTY BLUEPRINT, so the 24 encounter files each say only what makes them that party. Ordinary
-- traffic (`kind = "combat"`), on every floor from its opening one down (`depth`), weighted to a share
-- of the floor that Descent.floorPool sets rather than this file (Adventurers.SHARE), and allowed its
-- full six past the skirmish cap.
function Adventurers.party(spec)
    assert(spec.id and spec.name and spec.core and spec.grow, "a party needs id, name, core and grow")
    return {
        name = spec.name,
        kind = "combat",
        party = true,
        core = spec.core,
        grow = spec.grow,
        -- The approved words, printed by the wiki's Adventurers page (tools/wiki_gen.lua).
        combo = spec.combo,
        counter = spec.counter,
        depth = Adventurers.openingFloor(spec.core),
        weight = 1,
        enemyCap = Adventurers.MAX,
        composition = Adventurers.compose(spec.id, spec.core, spec.grow),
    }
end

-- PARTIES TAKE THIS SHARE OF A FLOOR'S ORDINARY DRAWS, split evenly among the parties eligible there
-- (round 1, the author's note: "Let's do 20%"). The circle's own species keep the rest.
Adventurers.SHARE = 0.20

-- ---------------------------------------------------------------------------
-- Variants: the blueprint a fielded body actually is
-- ---------------------------------------------------------------------------

-- `character_adv_bulwark@dwarf` as a blueprint: the race-free body with the race put on, named for both
-- ("Dwarf Bulwark"), carrying its pairing's race item if it has one. Built once per id and memoized by
-- the caller (Character.defs' __index). nil for anything that is not a valid variant, so a typo is the
-- same loud "unknown character id" as any other.
function Adventurers.variant(defs, id)
    local baseId, race = Adventurers.split(id)
    if not race then return nil end
    local base = rawget(defs, baseId)
    local Race = require("models.race")
    if not (base and Race.get(race)) then return nil end
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    out.race = race
    out.kind = Race.kindOf(race)
    out.variantOf = baseId
    local raceName = (Race.get(race).name or race)
    out.name = raceName .. " " .. (base.name or baseId)
    local items = {}
    for i, it in ipairs(base.startingItems or {}) do items[i] = it end
    local class = Adventurers.classOf(baseId)
    local extra = Adventurers.raceItemOf(race, class)
    if extra then items[#items + 1] = extra end
    out.startingItems = items
    return out
end

return Adventurers
