-- Muster: how much fight a body is worth, and how a company's worth stands against an encounter's.
--
-- Nothing in the game rated strength before this. LEVEL cannot do it: Player.syncLevels pins every
-- roster member to one prestige-derived level, and stat growth is flat by design (docs/progression.md),
-- so two companies at the same level differ only in what they are carrying -- which is exactly the
-- thing a level reading is blind to. So the ruler is EFFECTIVE STATS, gear folded in, through
-- Character.statTotal: the same numbers the Loadout sheet prints, which is what makes the reading
-- checkable by a player who wonders why a marker is the colour it is.
--
-- ONE FUNCTION, BOTH SIDES. Muster.rate is applied to the company and to the encounter alike; a
-- comparison between two different rulers would be a number about the rulers rather than about the
-- fight. The encounter's bodies are minted with Growth.spawn at the level the fight will actually
-- spawn them at, so this is not an estimate of the far side -- it is the far side.
--
-- Read two ways, and they are the same fact:
--   * continuously, as a BAND -- what an overworld marker is coloured and pipped by, which says how this
--     fight stands to you before you commit the step (ui/overworld_map.lua);
--   * against WALK_OVER, as the gate on auto-resolving a fight you have outgrown (states/game.lua).
-- Because the gate is the floor of the top band, the pip's top colour and the offer of the option
-- cannot disagree.
--
-- Pure (no love.graphics, no Combat, no panel), so it loads under the headless tests.

local Character = require("models.character")
local Growth = require("models.growth")
local Arena = require("models.arena")
local Player = require("models.player")

local Muster = {}

-- ---------------------------------------------------------------------------
-- The ruler
-- ---------------------------------------------------------------------------

-- What a body is worth, per point of each stat. Coefficients, not knobs: these are the solver's
-- business and nothing outside this file names one. The authored knob is WALK_OVER, in percent.
--
-- Health is the unit the others are priced against (1 point of health = 1 point of muster), which is
-- why the scale reads in the low hundreds -- roughly "how much damage this body is worth on the board".
Muster.STAT_WEIGHTS = {
    health = 1.0, -- the ceiling, gear included; `current` is deliberately not read (see rate)
    offense = 4.0, -- the better of the two arms, not their sum (see rate)
    defense = 3.0, -- the average of the two guards, since a fight comes at you both ways
    speed = 2.0, -- turns are the resource everything else is spent from
}

-- One body, gear folded in.
--
-- Two deliberate shapes in here:
--   * OFFENSE IS A MAX, not a sum. A body swings with its better arm; summing damage and magicDamage
--     would price a mediocre hybrid above a specialist who actually hits harder.
--   * HEALTH IS THE CEILING, not the current pool. This rates what a company can BRING, and a member
--     walking in at half health brings the same body -- the wound is the fight's problem, not the
--     roster's. It also keeps a marker's reading still while the party walks past it.
function Muster.rate(char)
    if not char then return 0 end
    local w = Muster.STAT_WEIGHTS
    local stat = function(key) return Character.statTotal(char, key) or 0 end

    local offense = math.max(stat("damage"), stat("magicDamage"))
    local defense = (stat("defense") + stat("magicDefense")) / 2

    local worth = stat("health") * w.health
        + offense * w.offense
        + defense * w.defense
        + stat("speed") * w.speed

    -- ...AND THE HEADS IT GROWS. A head is a body of its own on the board -- its own turn, its own
    -- health, its own blow (Combat.spawnHeads) -- but it is grown by an ITEM at the bell, so it is in no
    -- composition and no roster. Without this a chimera was rated as its lion alone, and the floor's
    -- light-fight filter (Descent.floorPool) threw the whole fight out as too cheap to deal. Minted at
    -- the bearer's own level, exactly as Combat.growHead mints it; a head grows no heads of its own.
    for _, item in ipairs(Character.eachItem(char) or {}) do
        if item and item.head and Character.defs[item.head] then
            local head = Character.instantiate(item.head)
            Growth.resolve(head, char.level or 1)
            worth = worth + Muster.rate(head)
        end
    end
    return worth
end

-- A list of bodies, summed.
--
-- A plain sum, and the head-count is deliberately NOT weighted on top of it. Action economy really is
-- super-linear (Arena.ENEMY_CAP's comment makes the case: four units against seventy eat seventy
-- attacks a round and land four), and a term for it was considered and declined -- the enemy cap
-- already bounds the count, and a second correction for the same thing would double-price it. If this
-- ever needs revisiting, revisit the cap.
function Muster.company(chars)
    local total = 0
    for _, char in ipairs(chars or {}) do total = total + Muster.rate(char) end
    return total
end

-- ---------------------------------------------------------------------------
-- The two sides
-- ---------------------------------------------------------------------------

-- The bodies who WOULD take the field, in the order the deployment phase would pre-select them: the
-- ones fielded last fight first (Player.lastDeployed), topped up from the roster to MAX_FIELD.
--
-- The fielded four, not the whole roster. The company that marches may be twelve, but four fight, and
-- rating twelve against a pack of four would say a fight is walkable on the strength of eight bodies
-- who will be standing on the bench while it happens.
function Muster.fielded(player)
    if not player then return {} end
    local picked, seen = {}, {}
    for _, char in ipairs(player.roster or {}) do
        if #picked >= Player.MAX_FIELD then break end
        if Player.wasDeployed(player, char) then
            picked[#picked + 1] = char
            seen[char] = true
        end
    end
    for _, char in ipairs(player.roster or {}) do
        if #picked >= Player.MAX_FIELD then break end
        if not seen[char] then picked[#picked + 1] = char end
    end
    return picked
end

-- The far side of an encounter, rated by the same ruler.
--
-- `def` is the encounter blueprint (models/encounter.lua); `ctx` carries `prestige`, the `quest` the
-- enemy cap is read off, and the fight's `floorLevel`. The composition is resolved and CLAMPED exactly
-- as Arena.build will clamp it, then each id is minted through Growth.spawn at the level
-- Growth.combatantLevel puts it at -- the same call states/battle.lua makes at spawn.
--
-- AND IT IS RATED AT THE MIDDLE OF THE BAND. A stop fields a rolled count rather than a fixed one
-- (models/band.lua), and the roll hangs off the fight's own seed -- which this ctx deliberately does
-- not carry, so every composition resolved here answers its centre. The bodies rated are the bodies
-- the board will seat give or take one piece of filler either way, which is inside the noise this
-- reading already carries from gear and the level the far side mints at.
function Muster.encounter(def, ctx)
    if not def then return 0 end
    ctx = ctx or {}
    local ids = Arena.resolveComposition(def.composition, ctx)
    -- The blueprint's own kind decides the fight TIER, so a marker is rated at the size the fight will
    -- actually open at (Arena.enemyCap). Taken from `def` rather than from `ctx` because the caller
    -- hands this function the blueprint and would otherwise have to remember to copy one field across
    -- -- and a muster that silently rated the wrong tier would mis-colour every marker on the board.
    ids = Arena.clampComposition(ids, Arena.enemyCap({
        quest = ctx.quest, encounterKind = def.kind, encounterCap = def.enemyCap,
    }))

    -- The level the fight will ACTUALLY spawn at, which is now a property of the calendar rather than
    -- of the company (models/calendar.lua). It used to be derived from the player's prestige, back when
    -- every roster member sat on one prestige-given level and "the party's level" was a single number
    -- that existed. It is not one number any more -- bodies earn their own -- and more to the point the
    -- world no longer scales to the party at all, which is the whole of what makes a spent day cost
    -- something. So the far side is minted at the day's danger level, and the near side is rated from
    -- the company's real stats (Muster.companyScore), which is where the comparison belongs.
    --
    -- ...and the calendar is the CAMPAIGN'S clock. A descent has none and hardens on depth instead, so
    -- it hands its own level in (Descent.dangerLevel). This reading is what colours the marker and what
    -- gates the walk-off (Muster.WALK_OVER), so it must be the level the fight will really spawn at --
    -- reading the day down a stair rated the first floor's stock at blueprint level 1 and turned every
    -- marker on it calm.
    -- ...and with the calendar deleted the fallback is the rift's own ladder. A caller that names no
    -- enemy level is rating a fight at a DEPTH, which Descent.dangerLevel answers directly -- the day
    -- was only ever that number laundered through a forty-day span and back.
    local danger = ctx.enemyLevel
        or require("models.descent").dangerLevel({ floor = ctx.depth or 1 })
    -- ...AND WHAT THE FIGHT PUT IN THEIR HANDS, keyed by body id (ctx.carried, off the cell). A mimic
    -- swings the chest it swallowed (models/mimic.lua), and a rating that minted it bare would price a
    -- body holding an axe as a body holding nothing -- which is the same failure the enemy-cap note
    -- above names: a marker that prices one fight and hands the player another is worse than no marker.
    local carried = ctx.carried
    local total = 0
    for _, id in ipairs(ids) do
        local ok, char = pcall(Growth.spawn, id, danger, ctx.floorLevel, carried and carried[id])
        if ok and char then total = total + Muster.rate(char) end
    end
    -- ...AND WHAT THE FIGHT IS DRESSED IN (ctx.dressing, off the cell): an affixed body, a condition, a
    -- rolled objective change the fight without changing the roster, so they are priced on top of it.
    return total * Muster.dressingFactor(ctx.dressing, ids)
end

-- ---------------------------------------------------------------------------
-- The dressing
-- ---------------------------------------------------------------------------

-- WHAT A FIGHT'S DRESSING IS WORTH (models/dressing.lua), as a multiplier on the roster's own worth.
--
-- Before this table every reading of a fight -- the marker's band and pips, the Run Away odds, the walk-off
-- gate -- was taken off the roster alone, so a pack with a Hexing alpha on a survive clock rated exactly
-- as the bare pack did and a dressed fight was always under-rated.
--
-- MEASURED, NOT AUTHORED: `. dressing-cost` (tools/dressing_cost.lua), 2026-10-25. Twelve ordinary
-- dressable fights (the two heaviest combats on each of floors 1-6), each played 24 seeds by the company a
-- new save carries at the floor's expected level, dice live, every dressed trial paired with the undressed
-- trial on the same seed (288 pairs; fewer for an objective, which only rosters that carry it can take).
-- COST is the share of the company's health a fight took, a loss counting as all of it; undressed, the
-- sample won 100% at a cost of 0.096. The RULER is the same fights with the enemy side's stats scaled so
-- its worth here rose a read +20 / +40 / +70%, which cost +0.069 / +0.183 / +0.355 (win 99 / 92 / 71%):
-- convex, so the points are joined up from the origin rather than fitted with one line. A dressing's
-- paired cost change read back through that curve is the worth increase that would cost an undressed fight
-- the same, and the multiplier is one plus it, rounded to 0.05. An effect inside two paired standard errors
-- is priced 1.00 -- a number there would be a number about the dice. Each row's comment is its cost change
-- and paired error (the same-seed repeat in one process matched 288 of 288, and three processes agreed on
-- every shared row, so the error is the seed sampling and nothing else). A multiplier under 1 is a dressing
-- that measured as HELPING the company -- a Break ends on its totem rather than on the whole pack, and Deep
-- Water's ford cost the company less than open ground did (measured, not explained). Re-run the tool after
-- retuning any of these and re-paste.
Muster.DRESSING = {
    -- Per affixed body: a fight with two carries the product of both.
    affix = {
        affix_armored = 1.00,   -- -0.000 +/- 0.006 (win -1.0 pts)
        affix_hexing = 1.10,    -- +0.038 +/- 0.005
        affix_rallying = 1.00,  -- +0.000 +/- 0.001
        affix_splitting = 1.05, -- +0.014 +/- 0.005 (+3.8 unit-turns)
        affix_steadfast = 1.00, -- -0.001 +/- 0.002
        affix_swift = 1.00,     -- +0.009 +/- 0.006
        affix_thorned = 1.00,   -- +0.000 +/- 0.000
        affix_vampiric = 1.00,  -- +0.002 +/- 0.001
        affix_volatile = 1.00,  -- +0.001 +/- 0.001 (past the noise, under half a step)
        affix_warded = 1.00,    -- +0.002 +/- 0.002
    },
    condition = {
        condition_burning_ground = 1.00, -- -0.003 +/- 0.003
        condition_darkness = 1.00,       -- +0.008 +/- 0.008
        condition_deep_water = 0.90,     -- -0.028 +/- 0.007
        condition_fog = 1.00,            -- +0.001 +/- 0.002
        condition_rain = 1.00,           -- -0.001 +/- 0.006
        condition_tremors = 1.00,        -- -0.002 +/- 0.002
    },
    -- A rolled kind, against kill-all on the same roster. Applied only where the roster carries it
    -- (Dressing.compatible), since a roster that cannot is fought as a kill-all (Dressing.materialize).
    objective = {
        assassinate = 1.00, -- +0.012 +/- 0.015 (48 pairs)
        ["break"] = 0.80,   -- -0.065 +/- 0.026 (24 pairs: one roster in the sample fields an object)
        hold = 1.00,        -- +0.008 +/- 0.007
        reach = 1.10,       -- +0.033 +/- 0.011 (win -3.6 pts)
        survive = 1.15,     -- +0.051 +/- 0.010 (win -1.4 pts, +16.9 unit-turns)
    },
}

-- The multiplier a dressing puts on a roster's worth: each affix once per body that can wear it (at most
-- Affix.MAX, the highest-tier bodies first -- Affix.assign's own rule, so a roster with one eligible body
-- prices one affix), then the condition, then the objective where the roster carries it. 1 for a fight
-- dressed in nothing. `ids` is the roster being rated; with none, every affix and the objective count.
function Muster.dressingFactor(dressing, ids)
    if type(dressing) ~= "table" then return 1 end
    local t = Muster.DRESSING
    local factor = 1
    if type(dressing.affixes) == "table" then
        local Affix = require("models.affix")
        local wearers = Affix.MAX
        if ids then
            wearers = 0
            for _, id in ipairs(ids) do if Affix.canWear(id, nil) then wearers = wearers + 1 end end
        end
        for k, id in ipairs(dressing.affixes) do
            if k > math.min(wearers, Affix.MAX) then break end
            factor = factor * (t.affix[id] or 1)
        end
    end
    if dressing.condition then factor = factor * (t.condition[dressing.condition] or 1) end
    if dressing.objective and (not ids or require("models.dressing").compatible(dressing.objective, ids)) then
        factor = factor * (t.objective[dressing.objective] or 1)
    end
    return factor
end

-- WHAT THE FIGHT STANDING ON A MAP CELL IS WORTH, the one door states/game.lua's cellMuster prices a
-- marker through. Pure, so the wiring is held by a spec and not only by the state: the marker, the Run
-- Away odds and the walk-off gate all read this one number (game:musterMargin).
--
-- `floor` is the reading's floor ctx: { depth, enemyLevel, quest, floorLevel }. Off the cell come the
-- three things the blueprint does not know -- a guarded pack's cast, a mimic's swallowed kit, and the
-- dressing the map stamped. Nil for a cell with nothing to rate.
function Muster.encounterCell(cell, floor)
    local enc = cell and cell.encounter
    local def = enc and enc.id and require("models.encounter").get(enc.id)
    -- A GUARDED PACK IS RATED OFF THE CELL, because that is where its cast is: the company standing
    -- over a dropped bag was drawn once, when the party fell, and stored on the drop
    -- (models/descent.lua's Descent.packGuard). Its blueprint deliberately carries no composition,
    -- so rating the blueprint would price every pile on the board as the resolver's default body.
    if enc and enc.kind == "pack" and enc.composition then
        def = { kind = "pack", composition = enc.composition }
    end
    if not def then return nil end
    floor = floor or {}
    return Muster.encounter(def, {
        depth = floor.depth,
        enemyLevel = floor.enemyLevel,
        quest = floor.quest,
        floorLevel = floor.floorLevel,
        -- ...and what the fight is HOLDING, for the same reason the pack is rated off the cell: a
        -- mimic's kit is the chest it swallowed and lives nowhere but here (models/mimic.lua), so a
        -- rating off the blueprint alone would price it as a body with one bite and nothing else.
        carried = enc.carried,
        dressing = enc.dressing,
    })
end

-- ---------------------------------------------------------------------------
-- The reading
-- ---------------------------------------------------------------------------

-- How the company stands against the fight, as a PERCENT: 100 is an even match, 200 is twice their
-- worth. A percent rather than a raw ratio because that is the unit the knob below is authored in and
-- the unit a designer thinks in; the abstract score itself is never printed anywhere.
--
-- A fight worth nothing (an empty or unresolvable composition) reads as nil rather than infinity --
-- there is no comparison to make, and a caller must not draw a band for one.
function Muster.margin(ours, theirs)
    if not (ours and theirs) or theirs <= 0 then return nil end
    return (ours / theirs) * 100
end

-- The bands, in percent, lowest first. Each entry is { name, min } and holds up to the next one's min.
--
-- Named for HOW FAR ABOVE YOU THE FIGHT IS, because that is the only thing a player wants from them.
-- The authored tier says how hard a fight is in the abstract, the same number for everyone who walks
-- past it -- which is a fact about the encounter table, not about this run. What a marker has to answer
-- is "is this above me, and by how much", and the answer moves as the company kits up.
--
-- So the scale is one-sided on purpose. Being FURTHER ahead than "beneath you" changes nothing you
-- would do -- the fight is already skippable -- so there is one band for it and no ladder of
-- increasingly emphatic safety. Everything below it is a real fight, and only THAT half is graded.
Muster.BANDS = {
    { name = "above3", min = 0 },   -- far above you
    { name = "above2", min = 40 },
    { name = "above1", min = 60 },
    { name = "even", min = 85 },    -- an even fight, or you slightly ahead: still costs you
    { name = "beneath", min = 200 },
}

-- How many pips a band draws: the number of STEPS the fight stands above the company. Zero for a fight
-- that is even or beneath you -- an even fight is not "one pip of danger", it is no pips and a marker
-- that still reads as a fight. The count only ever means "worse than even, by this much".
Muster.PIPS = { beneath = 0, even = 0, above1 = 1, above2 = 2, above3 = 3 }

-- What each band is called on screen. Kept here beside the bands themselves so the marker and the HUD
-- line that names the same fight cannot drift into calling one thing two names.
Muster.BAND_LABEL = {
    beneath = "Beneath you",
    even = "An even fight",
    above1 = "A step above you",
    above2 = "Two steps above you",
    above3 = "Far above you",
}

-- The gate on auto-resolving a fight, in percent of the encounter's worth. Deliberately the floor of
-- the top band and not a number of its own: the marker that goes calm and the option that appears are
-- one fact, and two constants could drift into saying different things about the same tile.
Muster.WALK_OVER = 200

-- How many steps above the company this fight stands: 0 when it is even or beneath them. The pip
-- count, and the single question the marker is drawn from.
function Muster.stepsAbove(margin)
    return Muster.PIPS[Muster.band(margin) or "even"] or 0
end

-- Which band a margin sits in. Nil in, nil out -- a fight with no reading has no band.
function Muster.band(margin)
    if not margin then return nil end
    local band = Muster.BANDS[1].name
    for _, entry in ipairs(Muster.BANDS) do
        if margin >= entry.min then band = entry.name end
    end
    return band
end

-- Has the company outgrown this fight? The single question states/game.lua asks before offering to
-- walk it off. Nil margin (nothing to compare) is not a walkover.
function Muster.canWalkOver(margin)
    return margin ~= nil and margin >= Muster.WALK_OVER
end

return Muster
