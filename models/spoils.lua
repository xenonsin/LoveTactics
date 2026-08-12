-- Battle spoils: the gold, loot and salvage a won fight hands over. Gold is still COMPUTED from
-- the size of the roster that was beaten and the company's prestige -- richer fights the deeper the
-- run. An encounter may override either half (rewardGold / loot on its blueprint), mirroring how a
-- treasure cache authors its own `loot` list (data/encounters/encounter_treasure.lua).
--
--   local s = Spoils.roll({ enemyUnits = battle.enemyUnits, prestige = 3, kind = "combat" })
--   -- s = { gold = 71, loot = { "consumable_healing_potion" },
--   --       materials = { material_iron_scrap = 1 } }
--
-- The third field is the FLOOR, and unlike the other two it is not a roll -- see "Salvage" below.
--
-- The same price band also stocks the road's one shop, the Merchant (Spoils.shelf) -- what a run can
-- turn up is one question whether the goods are taken off a body or bought off a cart.
--
-- LOOT COMES OFF THE BODIES FIRST. It used to be a price-banded random draw over every item in the
-- game, with no connection at all to the roster that was beaten -- there was no drop-table
-- authoring, so there was nothing to connect it to. That was invisible while enemies carried
-- interchangeable stock (nobody covets a bandit's iron sword), and stops being invisible the moment
-- the bestiary lands: the whole pitch of a discipline Elite is "I want the thing he just used," and
-- answering that with a rolled healing potion is the wrong answer to a question the fight itself
-- asked (docs/bestiary.md).
--
-- So the roll draws from the CARRIED pool -- the priced, unbound items the beaten roster actually
-- had in its grids -- and falls back to the old price band when that pool is empty. The fallback is
-- not a legacy path: a wolf pack carries nothing priced (a creature's natural weapons are unpriced
-- and `noSteal`, docs/bestiary.md), and a fight that pays nothing at all is worse than one that pays
-- a potion. CARRIED_BIAS keeps a slice of the band even when there IS a body worth looting, so
-- consumables still turn up in fights against people who weren't carrying any.
--
-- No price band applies to a carried drop, and that is the point rather than an oversight: if you
-- beat something wielding a relic, being able to walk away with the relic is the reward. `bound` is
-- still honoured, which is what keeps a boss's phase machinery (utility_demon_sigil and its
-- trait_boss_phases) out of the player's hands.
--
-- Pure logic, no love.graphics at require time -- loads under the headless test runner. RNG falls
-- back to math.random when love.math is unavailable, so the roll is exercisable outside a window.

local Item = require("models.item")
local Character = require("models.character")
local Material = require("models.material")

local Spoils = {}

-- WHAT A FIGHT PAYS, and why it is no longer mostly a head-count.
--
-- Gold used to be `GOLD_PER_ENEMY * count * prestige` -- purely linear in how many bodies stood there.
-- That was survivable while every fight was a set-piece of nine, and became wrong the moment an
-- ordinary road stop dropped to a skirmish of three (Arena.SKIRMISH_CAP): the same fight, taking the
-- same health and the same consumables and carrying the same risk to the run, would have paid a third
-- of what it used to. Cutting the bodies without moving this is not a rebalance, it is a pay cut.
--
-- So a fight pays for BEING a fight, plus a little for its size. The flat half is the larger half at
-- skirmish scale, which is the point: what a stop costs the player is mostly the fact of stopping --
-- the attrition, the turns, the risk -- and only partly how many bodies were on it.
local GOLD_PER_FIGHT = 30   -- what clearing a stop is worth at all, before anything is counted
local GOLD_PER_ENEMY = 8    -- ...and what each body standing on it adds
local ELITE_GOLD_MULT = 1.8 -- an elite fight pays out richer than a like-sized common one

-- HOW MUCH RICHER A FLOOR GETS FOR BEING DEEPER, per level of depth. Not the raw multiplier prestige
-- is, and the difference is the whole reason this constant exists.
--
-- Prestige is FIXED for the length of a quest -- the company walks in at 13 and walks out at 13 -- so
-- multiplying by it prices one run against another and nothing within a run compounds. A descent's
-- floor level is not fixed: it climbs two per stair (Descent.LEVEL_PER_FLOOR), eight times in a long
-- run. Reusing prestige's slope there would have the seventh floor paying thirteen times the first,
-- and MEASURED -- the whole floor walked, caches included -- that is a floor handing over eleven
-- thousand gold against a shelf whose dearest row is authored at a few hundred (Grade.priceFor). Gold
-- would stop being a decision somewhere on floor three.
--
-- So depth pays a shallow slope instead: floor 1 pays flat, and each level after adds a fifth. Floor 7
-- comes out around three and a half times floor 1 -- materially richer, which is the greed the landing
-- question needs, and still inside the band where one cleared floor buys roughly one thing off a shelf.
local GOLD_DEPTH_SLOPE = 0.2
-- The chance a given drop is drawn off the beaten bodies rather than the generic price band, when
-- both pools have something in them. Not 1.0: at 1.0 a fight against people who happened to carry
-- no consumables can never pay a potion, and the band is the only thing that stocks the everyday
-- restock. Three drops in four coming off the corpse is enough for the connection to read.
local CARRIED_BIAS = 0.75

-- love.math.random when running under LÖVE, else math.random. Same call signatures: () -> [0,1),
-- (m) -> [1,m], (m,n) -> [m,n]. Kept behind one helper so the whole module is engine-agnostic.
local function rnd(...)
    if love and love.math and love.math.random then return love.math.random(...) end
    return math.random(...)
end

-- Gold for beating `count` enemies at `depth`, scaled by the encounter's difficulty tier (`scale`,
-- default 1) so a tougher side-fight pays materially more -- the risk/reward that makes engaging a
-- fight before the boss worth the attrition. An override short-circuits the whole computation (it is
-- an exact, authored payout and is never rescaled).
--
-- `mult` is HOW FAR IN this fight is, already resolved to a multiplier by the caller (Spoils.roll),
-- because the game has two shapes of run and they read depth differently -- prestige straight in the
-- campaign, a shallow slope over the floor level in a descent. See GOLD_DEPTH_SLOPE for why they are
-- not the same slope, and Spoils.roll for which one a given call gets.
local function rollGold(count, mult, kind, override, scale)
    if override then return math.max(0, math.floor(override)) end
    local base = (GOLD_PER_FIGHT + GOLD_PER_ENEMY * math.max(1, count)) * math.max(1, mult)
    local jitter = 0.85 + rnd() * 0.30 -- +/-15% so two identical fights don't pay identically
    local gold = base * jitter * (scale or 1)
    if kind == "elite" then gold = gold * ELITE_GOLD_MULT end
    return math.max(1, math.floor(gold + 0.5))
end

-- The ceiling of the ROAD BAND on `day`: how dear a thing a run can turn up at all. One number,
-- because the road turns goods up two ways -- off a beaten body and off the Merchant's shelf
-- (Spoils.shelf) -- and a market carrying gear the same road could never drop would be a second,
-- silent answer to a question this already answers.
--
-- IT USED TO READ PRESTIGE, and the band got narrower when it moved. Prestige ran to 93 over a
-- campaign, so the deepest road could drop a 5,620-gold piece; the calendar runs to 40, which tops out
-- near 2,440. That is a real cut to what the road can hand over and it is the right one -- a campaign
-- with a deadline is shorter, the shelves are shallower for the same reason (docs/overworld.md), and a
-- road that out-dropped the shops it is supposed to feed was already the wrong shape.
local function bandPrice(day)
    return 40 + math.max(1, day or 1) * 60
end

-- The drop pool: every PRICED item within a prestige-scaled price band. Price is the "shoppable"
-- marker -- natural weapons, bound relics and quest items have none, so they can never drop. Cheaper
-- items (and consumables) weight heavier, so the common reward is a potion, not the best sword you
-- could theoretically afford.
local function lootCandidates(maxPrice)
    local pool = {}
    for id, def in pairs(Item.defs) do
        if def.price and def.price > 0 and def.price <= maxPrice and not def.bound then
            local weight = 1 + math.max(0, maxPrice - def.price) / maxPrice -- ~1 (dear) .. ~2 (cheap)
            if def.type == "consumable" then weight = weight * 2 end
            pool[#pool + 1] = { id = id, weight = weight }
        end
    end
    return pool
end

-- The carried pool: every priced, unbound item in the beaten roster's grids. One entry per item
-- CARRIED rather than per distinct id, so four bandits with iron swords make an iron sword four
-- times as likely to fall out -- "what you defeat" includes how much of it there was.
--
-- Tolerant about the shape it is handed, because the callers differ: a live battle passes real
-- units, and a test or a headless caller may pass bare `{ char = { id = ... } }` stand-ins with no
-- grid at all. A body with no inventory contributes nothing instead of erroring.
local function carriedCandidates(enemyUnits)
    local pool = {}
    if not enemyUnits then return pool end
    for _, unit in ipairs(enemyUnits) do
        local char = unit and unit.char
        if char and char.inventory then
            for _, item in ipairs(Character.eachItem(char)) do
                local def = item.id and Item.defs[item.id]
                if def and def.price and def.price > 0 and not def.bound then
                    pool[#pool + 1] = { id = item.id, weight = 1 }
                end
            end
        end
    end
    return pool
end

-- Weighted draw of one id from a { id, weight } pool, or nil for an empty pool.
local function pick(pool)
    if #pool == 0 then return nil end
    local total = 0
    for _, e in ipairs(pool) do total = total + e.weight end
    local r = rnd() * total
    for _, e in ipairs(pool) do
        r = r - e.weight
        if r <= 0 then return e.id end
    end
    return pool[#pool].id -- float slop guard: the last entry mops up the remainder
end

-- 0-2 loot ids. An override list is used verbatim (unknown ids dropped so a typo can't crash the
-- later Item.instantiate). Otherwise: a likely first drop and an unlikely second, both richer and
-- more probable for an elite.
-- `scale` (default 1) is the difficulty-tier bump. A gentler curve than gold uses -- sqrt(scale) --
-- widens the price band and lifts both drop chances, so a tier-3 fight tends to pay a richer, likelier
-- drop without a low-prestige map suddenly raining top-shelf gear.
local function rollLoot(day, kind, override, enemyUnits, scale)
    if override then
        local out = {}
        for _, id in ipairs(override) do
            if Item.defs[id] then out[#out + 1] = id end
        end
        return out
    end
    local bump = math.sqrt(scale or 1)
    local elite = kind == "elite"
    local maxPrice = bandPrice(day)
    if elite then maxPrice = maxPrice * 1.5 end
    maxPrice = maxPrice * bump
    local band = lootCandidates(maxPrice)
    local carried = carriedCandidates(enemyUnits)

    -- One drop: off a body when there is one to loot and the bias says so, else out of the band.
    -- Each drop rolls its own source, so a two-drop fight can pay one of each.
    local function draw()
        if #carried > 0 and rnd() < CARRIED_BIAS then return pick(carried) end
        return pick(band)
    end

    local out = {}
    if rnd() < math.min(0.95, (elite and 0.90 or 0.55) * bump) then
        local id = draw(); if id then out[#out + 1] = id end
    end
    if rnd() < math.min(0.80, (elite and 0.45 or 0.18) * bump) then
        local id = draw(); if id then out[#out + 1] = id end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- The Merchant's shelf: the same band, bought instead of taken
-- ---------------------------------------------------------------------------

-- `count` DISTINCT item ids for the wandering Merchant to stock (data/encounters/encounter_merchant.lua),
-- drawn out of the very band a fight's loot rolls in: priced, unbound, and no dearer than the road pays
-- at this prestige. The weighting comes along with it, so a shelf leans the way the drop table does --
-- mostly supplies, the occasional piece of gear worth the detour.
--
-- Ids only. What each COSTS is the item's own shelf price, which belongs to the item and not to a roll:
-- the Merchant charges what the houses charge, since a markup the player cannot compare against a hub
-- they are three stops from is a tax rather than a decision.
--
-- `exclude` is an optional bare set of ids to keep off the shelf. Returns fewer than `count` (or
-- nothing) when the band is too thin to fill it, which the caller must handle -- a market with an empty
-- shelf is a stop with nothing on it.
function Spoils.shelf(opts)
    opts = opts or {}
    local count = math.max(0, opts.count or 3)
    local taken = {}
    for id in pairs(opts.exclude or {}) do taken[id] = true end

    local pool = lootCandidates(bandPrice(opts.day))
    local out = {}
    for _ = 1, count do
        local available = {}
        for _, entry in ipairs(pool) do
            if not taken[entry.id] then available[#available + 1] = entry end
        end
        local id = pick(available)
        if not id then break end
        taken[id] = true
        out[#out + 1] = id
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Salvage: the floor under every won fight
-- ---------------------------------------------------------------------------

-- EVERY won fight hands over forging material, whatever else it does or does not roll. Gold and loot
-- are both chances -- loot especially, whose first drop lands a little over half the time, so nearly
-- half of all common fights used to pay a number on a panel and nothing you could carry home. A fight
-- costs HP, consumables and a real chance of losing the run; paying out nothing is the one outcome the
-- board cannot justify having walked into.
--
-- So this half is COMPUTED, never rolled: no RNG, no zero case, and (deliberately) no per-encounter
-- override to author it away. It is also the SMALLEST payout in the economy, because a cache still
-- pays 1-4 craft and 1-3 house stock (Overworld:placeCaches) and leaving the path is meant to stay the
-- thing that stocks the Forge (docs/progression.md, "Materials as a reason to leave the path"). This
-- is a floor, not a rival: one ingot for clearing a stop, two for an elite or a general.
--
-- HELD, NOT MOVED, when the gold beside it was rebased for the skirmish tier -- and measured rather
-- than assumed, because the arithmetic points the wrong way until the caches are counted. A whole
-- descent floor walked stop by stop pays around six craft and six house, against a Forge rung billing
-- four-to-six craft and two-to-three house (models/forge.lua): one floor, one rung, which is the rule
-- the rebase was against. Head-count never fed this half, so shrinking the fights could not cut it.
--
-- What DOES move it is the number of caches, which is derived from the stop count (Overworld.generate,
-- about one per two stops) and so triples the moment a floor gets dense. See Descent.FLOOR_STOPS,
-- where that bump is a one-line change and this is the thing it has to be checked against.
local SALVAGE_CRAFT = { combat = 1, elite = 2, objective = 2 }
-- House stock -- the GATE half of the economy, the one that decides which house's bench a haul feeds
-- -- is the reward for the fights you could have walked around, and for the one you came for. A common
-- fight on the road never pays it; an elite and the objective pay one apiece.
local SALVAGE_HOUSE = { elite = 1, objective = 1 }

-- Which craft grade falls out of a fight: its DIFFICULTY TIER (1..3, stamped on the encounter by
-- models/overworld.lua -- the same tell the fog shows before you commit), bumped a grade for an elite
-- or an objective. What you beat decides what it leaves behind, which is exactly what the tier is
-- already there to say. Never forge depth: that mapping died with Material.TIER_BY_LEVEL, and the
-- reasoning is in models/material.lua.
local function craftGradeFor(kind, tier)
    local grades = Material.craftGrades()
    local i = math.max(1, math.min(#grades, math.floor(tonumber(tier) or 1)))
    if kind == "elite" or kind == "objective" then i = math.min(#grades, i + 1) end
    return grades[i]
end

-- The materials a won fight hands over, as { [id] = count }. NEVER EMPTY -- that is the whole point.
--   opts.kind          "combat" | "elite" | "objective" (anything else is treated as common)
--   opts.tier          the encounter's difficulty tier, 1..3 (default 1)
--   opts.houseMaterial the run's house stock -- the quest sponsor's, resolved by the caller exactly as
--                      the map's caches resolve it (states/game.lua). Absent on an unsponsored leg
--                      (the prologue), where the fight simply pays craft stock alone.
--
-- Exposed separately from Spoils.roll because the objective fight takes this half and not the other:
-- a quest's gold and loot flow through Quest.complete, but the general still has to leave something on
-- the sand like everything else on the road did.
function Spoils.materials(opts)
    opts = opts or {}
    local kind = opts.kind or "combat"
    local out = {}
    out[craftGradeFor(kind, opts.tier)] = SALVAGE_CRAFT[kind] or SALVAGE_CRAFT.combat
    local house = SALVAGE_HOUSE[kind] or 0
    -- An id no longer in data/materials is dropped rather than granted, the same rule the loot
    -- override follows -- a stale save or a removed house must not mint a phantom resource.
    if house > 0 and opts.houseMaterial and Material.get(opts.houseMaterial) then
        out[opts.houseMaterial] = (out[opts.houseMaterial] or 0) + house
    end
    return out
end

-- Roll the spoils for a won fight.
--   opts.enemyUnits  the beaten roster (its length is the count); or pass opts.count directly
--   opts.day    the company's prestige (default 1)
--   opts.floorLevel  a descent floor's level, if this fight is on one. Its presence SWITCHES how the
--                    gold reads depth -- a shallow slope over the floor instead of a straight multiple
--                    of prestige (GOLD_DEPTH_SLOPE) -- so nothing moves in the campaign, which has
--                    never passed one
--   opts.kind        "combat" | "elite" (elite pays richer); anything else treated as common
--   opts.rewardGold  encounter override: exact gold, skipping the computation
--   opts.loot        encounter override: an explicit id list, skipping the roll
--   opts.rewardScale difficulty-tier multiplier (default 1); scales the gold and, gentler, the loot.
--                    Absent/1 reproduces the pre-tier payout exactly. Overrides ignore it.
--   opts.tier        the encounter's difficulty tier 1..3, for the salvage grade (see Spoils.materials)
--   opts.houseMaterial the run's house stock, for an elite's salvage (see Spoils.materials)
--
-- `enemyUnits` now feeds BOTH rolled halves: its length sets the gold, and its grids are the drop
-- table. Passing `count` alone still works and still pays gold, it just has no bodies to loot, so the
-- roll falls back to the price band entirely.
--
-- The salvage draws no RNG, so a caller seeding the generator to compare two gold rolls still gets
-- the same numbers it did before this field existed.
function Spoils.roll(opts)
    opts = opts or {}
    local count = opts.count or (opts.enemyUnits and #opts.enemyUnits) or 1
    local day = opts.day or 1
    local kind = opts.kind or "combat"
    local scale = opts.rewardScale or 1
    -- HOW FAR IN this fight is, as the multiplier the gold is scaled by. A BRANCH rather than a max of
    -- the two, because the two numbers are not the same kind of thing (see GOLD_DEPTH_SLOPE): prestige
    -- is a fixed per-run standing and scales straight, a floor level climbs within the run and scales
    -- on a shallow slope. Taking the larger would let the descent inherit prestige's slope the moment a
    -- strong company went down, which is precisely the compounding this avoids.
    --
    -- On a descent the company's prestige is deliberately NOT consulted: floor 1 pays what floor 1 is
    -- worth however decorated the party that walks it, which is what stops a strong company farming the
    -- shallows instead of descending.
    local mult = opts.floorLevel
        and (1 + GOLD_DEPTH_SLOPE * (math.max(1, opts.floorLevel) - 1))
        or math.max(1, day)
    return {
        gold = rollGold(count, mult, kind, opts.rewardGold, scale),
        loot = rollLoot(day, kind, opts.loot, opts.enemyUnits, scale),
        materials = Spoils.materials({
            kind = kind, tier = opts.tier, houseMaterial = opts.houseMaterial,
        }),
    }
end

return Spoils
