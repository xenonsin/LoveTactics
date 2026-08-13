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
local Calendar = require("models.calendar") -- the far side is minted at the DAY's level, not the party's
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

    return stat("health") * w.health
        + offense * w.offense
        + defense * w.defense
        + stat("speed") * w.speed
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
-- Growth.combatantLevel puts it at -- the same call states/battle.lua makes at spawn. Compositions are
-- deterministic functions of ctx.prestige (no rng anywhere in data/encounters), so the bodies rated
-- here are the bodies that will stand on the board.
function Muster.encounter(def, ctx)
    if not def then return 0 end
    ctx = ctx or {}
    local ids = Arena.resolveComposition(def.composition, ctx)
    -- The blueprint's own kind decides the fight TIER, so a marker is rated at the size the fight will
    -- actually open at (Arena.enemyCap). Taken from `def` rather than from `ctx` because the caller
    -- hands this function the blueprint and would otherwise have to remember to copy one field across
    -- -- and a muster that silently rated the wrong tier would mis-colour every marker on the board.
    -- ...AND AT THE SIZE THE GROUND WILL ALLOW. The cap is a property of the board now, not only of the
    -- kind: a fight taken in a defile fields fewer bodies than the same encounter in a hall
    -- (Arena.enemyCap). The marker has to price the fight the player will actually meet, so it reads the
    -- same box the fight will be cut from -- ctx carries the grid and the tile where the caller has one,
    -- and where it does not this is nil and the rating is exactly what it always was.
    local usable = ctx.grid and ctx.at and Arena.boxUsable(ctx.grid, ctx.at.x, ctx.at.y) or nil
    ids = Arena.clampComposition(ids, Arena.enemyCap({
        quest = ctx.quest, encounterKind = def.kind,
    }, usable))

    -- The level the fight will ACTUALLY spawn at, which is now a property of the calendar rather than
    -- of the company (models/calendar.lua). It used to be derived from the player's prestige, back when
    -- every roster member sat on one prestige-given level and "the party's level" was a single number
    -- that existed. It is not one number any more -- bodies earn their own -- and more to the point the
    -- world no longer scales to the party at all, which is the whole of what makes a spent day cost
    -- something. So the far side is minted at the day's danger level, and the near side is rated from
    -- the company's real stats (Muster.companyScore), which is where the comparison belongs.
    local danger = Calendar.dangerLevel(ctx.day or 1)
    local total = 0
    for _, id in ipairs(ids) do
        local ok, char = pcall(Growth.spawn, id, danger, ctx.floorLevel)
        if ok and char then total = total + Muster.rate(char) end
    end
    return total
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
