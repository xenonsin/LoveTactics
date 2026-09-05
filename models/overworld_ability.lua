-- Companion OVERWORLD abilities: a passive party perk each recruit brings to traversal, in the spirit
-- of Dream Quest -- your party changes how the map plays. Each expresses that companion's virtue through
-- a distinct traversal metric, and each leans into a pillar of the overworld redesign (attrition,
-- skippable fights, tiered rewards). Kept SEPARATE from the combat trait system (models/trait.lua): a
-- combat trait rides on an equipped item and fires in a fight; an overworld ability is keyed to the
-- character and fires on the map.
--
-- CURRENTLY DETACHED. No character blueprint carries an `overworldAbility` field any more, so every
-- dispatch below is a no-op and the party strip draws no badge -- the definitions are kept for now
-- rather than deleted. The mapping, if it is reattached: Rowan/vigil, Saber/held_swing, Amana/
-- kept_trust, Ren/aqua_vitae, Kaya/forage, Gyeom/ledger, Clem/jubilee.
--
-- This is a registry + dispatcher, headless-safe (no love.graphics at require-time; RNG falls back to
-- math.random when love.math is absent). states/game.lua calls OverworldAbility.dispatch(event, ctx) on
-- four traversal events:
--   "step"             every landed tile (Kaya forages, Saber's held swing banks steps, ...)
--   "encounterCleared" a combat/elite win (Amana heals, Ren distils a dose, Rowan banks a vigil, ...)
--   "battleStart"      just before a fight launches (Rowan/Saber spend their banked readiness)
--   "objectiveReached" just before the boss (Ren pours the doses into a whole-party lift)
-- A handler gets (char, bucket, ctx): `bucket` is the ability's per-RUN scratch (auto-created, keyed by
-- the character), reset each quest like the fog; `ctx` = { player, party, grid, state, cell?, spoils? }.
--
-- The battle-affecting abilities (Rowan/Saber/Ren) act by RESTORING the party's carried resources before
-- the fight rather than reaching into combat: in an attrition game where HP/mana/stamina carry between
-- fights (models/player.lua), topping a pool back up IS the buff, and it never corrupts persistent state
-- (a refill is capped at max, and the hub restores everyone anyway).

local Player = require("models.player")
local Character = require("models.character")

local OverworldAbility = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function rnd(...)
    if love and love.math and love.math.random then return love.math.random(...) end
    return math.random(...)
end

local function pool(char, stat)
    local s = char.stats and char.stats[stat]
    return type(s) == "table" and s or nil
end

-- Top `stat` back up by `amount`, capped at its max. Returns how much was actually restored.
local function restore(char, stat, amount)
    local p = pool(char, stat)
    if not (p and p.max) then return 0 end
    local before = p.current or 0
    p.current = math.min(p.max, before + amount)
    return p.current - before
end

-- The party member furthest below full health (only those not already full), or nil.
local function mostWounded(party)
    local target, frac
    for _, c in ipairs(party) do
        local hp = pool(c, "health")
        if hp and (hp.max or 0) > 0 then
            local f = (hp.current or 0) / hp.max
            if f < 1 and (not frac or f < frac) then frac = f; target = c end
        end
    end
    return target
end

-- The front line: whoever the player actually stood nearest the enemy in this fight's deployment phase.
-- Supplied by the caller as `ctx.frontRow`, because only the battle knows it -- placement is chosen per
-- battle over the real board (docs/deployment.md), so there is no arrangement here in the overworld to
-- read. Falls back to the whole party, which is what a dispatch fired outside a battle (a test, a hook
-- with no board yet) should see: no line has formed, so everyone is on it.
local function frontRow(ctx, party)
    local supplied = ctx and ctx.frontRow
    if type(supplied) == "function" then supplied = supplied() end
    if type(supplied) == "table" and #supplied > 0 then return supplied end
    return party
end

local function anyoneDown(party)
    for _, c in ipairs(party) do
        local hp = pool(c, "health")
        if hp and (hp.current or 0) <= 0 then return true end
    end
    return false
end

local function isCombat(cell)
    local e = cell and cell.encounter
    -- `pack` is the fight standing over a company's own dropped kit (models/descent.lua). It reaches
    -- the arena on the ordinary path and costs the same health and potions, so the companions who
    -- react to a cleared fight -- Rowan's Vigil, Saber's patience, Amana's triage -- react to this one.
    return e and (e.kind == "combat" or e.kind == "elite" or e.kind == "pack")
end

-- Announce a visible effect (states/game.lua shows it as an overworld toast). A no-op if no notifier
-- was passed, so the module stays usable headlessly and in tests.
local function say(ctx, msg)
    if ctx.notify then ctx.notify(msg) end
end

-- Lift the fog off any RELIC CACHE (models/relic.lua) within `radius` of (x, y) -- how the prospector
-- (Kaya) senses reliquaries as she passes. Guarded on grid.cells so it is a no-op under the test stubs
-- and any grid that doesn't expose its cell table.
local function revealCachesNear(grid, x, y, radius)
    if not (grid and grid.cells and grid.reveal) then return end
    for dy = -radius, radius do
        local row = grid.cells[y + dy]
        if row then
            for dx = -radius, radius do
                local c = row[x + dx]
                if c and c.encounter and c.encounter.kind == "relic_cache" then grid:reveal(c.x, c.y, 1) end
            end
        end
    end
end

-- Lift the fog off EVERY relic cache on the board at once -- the scholar (Gyeom) mapping the whole region
-- when her study completes. Same guard as above.
local function revealAllCaches(grid)
    if not (grid and grid.cells and grid.reveal and grid.rows and grid.cols) then return end
    for yy = 1, grid.rows do
        for xx = 1, grid.cols do
            local c = grid.cells[yy][xx]
            if c and c.encounter and c.encounter.kind == "relic_cache" then grid:reveal(xx, yy, 1) end
        end
    end
end

-- ---------------------------------------------------------------------------
-- The abilities
-- ---------------------------------------------------------------------------

local A = {}

-- ROWAN -- Vigil (guardian). A fight cleared with the whole line still standing banks a vigil (capped);
-- a casualty breaks it. At the next fight the front row opens with a HEALTH buffer per vigil -- the
-- bodyguard steels the line before the blow. (Health carries into the fight; stamina would not -- combat
-- refills stamina at the bell, models/combat.lua.) Front-row + clean-streak-scaled + pre-fight, distinct
-- from Amana's flat after-fight triage of whoever is worst off.
A.vigil = {
    encounterCleared = function(_, bucket, ctx)
        if not isCombat(ctx.cell) then return end
        if anyoneDown(ctx.party) then bucket.vigils = 0; return end
        bucket.vigils = math.min(3, (bucket.vigils or 0) + 1)
        say(ctx, "Rowan holds the line (Vigil x" .. bucket.vigils .. ")")
    end,
    battleStart = function(_, bucket, ctx)
        local v = bucket.vigils or 0
        if v <= 0 then return end
        for _, c in ipairs(frontRow(ctx, ctx.party)) do restore(c, "health", 3 * v) end
    end,
}

-- SABER -- The Held Swing (patience). She is never in a hurry, and contentment is its own heal: the
-- longer since her last fight, the cleaner she comes through the next one. Banks ground COVERED -- each
-- tile counted once (cell.paced), the way Kaya's forage marks a tile once -- so pacing two tiles back and
-- forth mints nothing; only new road pays. On the win it heals her scaled by the distance, then resets.
-- (Health, not stamina -- see Rowan.) A patient route lets her shrug the next fight off; a wiggle does not.
A.held_swing = {
    step = function(_, bucket, ctx)
        local cell = ctx.cell
        if not cell or cell.paced then return end -- a tile already walked banks nothing (no pacing exploit)
        cell.paced = true
        bucket.steps = (bucket.steps or 0) + 1
    end,
    encounterCleared = function(char, bucket, ctx)
        if not isCombat(ctx.cell) then return end
        local healed = restore(char, "health", math.min(14, math.floor((bucket.steps or 0) / 2)))
        bucket.steps = 0
        if healed > 0 then say(ctx, "Saber's patience pays (+" .. healed .. ")") end
    end,
}

-- AMANA -- The Kept Trust (devotion). "Gives what is offered, returned intact": after each fight she
-- heals the most-wounded, keeping nothing for herself. Softens the very attrition her line answers.
A.kept_trust = {
    encounterCleared = function(_, _, ctx)
        if not isCombat(ctx.cell) then return end
        local t = mostWounded(ctx.party)
        if t then
            local healed = restore(t, "health", 12)
            if healed > 0 then say(ctx, "Amana heals " .. (t.name or "an ally") .. " (+" .. healed .. ")") end
        end
    end,
}

-- REN -- Aqua Vitae (kindness). Every side-fight won distils a dose; reaching the objective she pours
-- them ALL into the whole party (HP + mana), scaling with how many fights you dared. Kindness levels up:
-- the more you engaged before the boss, the stronger the party arrives at it -- the risk/reward engine.
A.aqua_vitae = {
    encounterCleared = function(_, bucket, ctx)
        if not isCombat(ctx.cell) then return end
        bucket.doses = (bucket.doses or 0) + 1
        say(ctx, "Ren distils a dose (" .. bucket.doses .. ")")
    end,
    objectiveReached = function(_, bucket, ctx)
        local d = bucket.doses or 0
        if d <= 0 then return end
        for _, c in ipairs(ctx.party) do
            restore(c, "health", 6 * d)
            restore(c, "mana", 4 * d)
        end
        say(ctx, "Ren pours " .. d .. " dose" .. (d == 1 and "" or "s") .. " into the party")
    end,
}

-- KAYA -- Forage (temperance). The guide who runs the wild: each newly explored tile (dead-ends most of
-- all) may turn up a little gold, but she takes no more than the road offers -- a hard cap per run. Gives
-- sweeping the dense board a point without making it mandatory.
local FORAGE_CAP = 40
A.forage = {
    step = function(_, bucket, ctx)
        local cell = ctx.cell
        if not cell or cell.foraged then return end
        cell.foraged = true
        -- The guide who runs the wild also reads it: reliquaries near her step surface through the fog,
        -- so a party with Kaya can route to the run's relics instead of stumbling onto them.
        revealCachesNear(ctx.grid, cell.x, cell.y, 2)
        bucket.gained = bucket.gained or 0
        if bucket.gained >= FORAGE_CAP then return end
        local deadEnd = ctx.grid and #ctx.grid:pathNeighbors(cell.x, cell.y) <= 1
        if rnd() < (deadEnd and 0.5 or 0.22) then
            local g = math.min(3 + math.floor(rnd() * 4), FORAGE_CAP - bucket.gained) -- 3..6, capped
            bucket.gained = bucket.gained + g
            if ctx.player and g > 0 then
                Player.addGold(ctx.player, g)
                say(ctx, "Kaya forages " .. g .. "g")
            end
        end
    end,
}

-- GYEOM -- The Ledger (humility). She reads the ground: while she travels with you vision is a tile
-- wider (OverworldAbility.visionBonus, below), and once she has banked enough study -- three fights --
-- she works out where the quarry waits and the fog lifts off the objective tile. Powers reveal-then-
-- choose + informed boss prep.
A.ledger = {
    encounterCleared = function(_, bucket, ctx)
        if not isCombat(ctx.cell) then return end
        bucket.study = (bucket.study or 0) + 1
        if bucket.study >= 3 and not bucket.revealed and ctx.grid and ctx.grid.objective then
            bucket.revealed = true
            ctx.grid:reveal(ctx.grid.objective.x, ctx.grid.objective.y, 1) -- the quarry's seat is read
            revealAllCaches(ctx.grid) -- ...and the whole region's reliquaries, mapped at a stroke
            say(ctx, "Gyeom reads the quarry's seat -- and every reliquary")
        end
    end,
}

-- CLEM -- Jubilee (clemency). The Bank's finest blade turned the craft around: she mints value and gives
-- it away. Her cut is added on top of every side-fight win -- the collector become the jubilee. Leans
-- into the redesign's greater side-fight rewards.
--
-- PAID IN SCRIP, on the fight's own coin (models/scrip.lua). A cut of a side-fight is a cut of what
-- that fight paid, and a rolled fight pays the run's purse -- taking a quarter of a fight's scrip and
-- handing back campaign gold would make this the one seam in the game that converts one into the other,
-- which is the exact thing the split exists to prevent. It reads the same number it always did; only
-- the purse it lands in moved.
A.jubilee = {
    encounterCleared = function(_, _, ctx)
        if not isCombat(ctx.cell) then return end
        -- Read off `gold` rather than the retired `scrip` field: one purse now (models/spoils.lua),
        -- and a rolled fight pays it at the same number the split had it paying the other one.
        local base = ctx.spoils and ctx.spoils.gold or 0
        local bonus = math.max(3, math.floor(base * 0.25))
        if ctx.player then
            require("models.player").addGold(ctx.player, bonus)
            say(ctx, "Clem's cut  +" .. bonus .. "g")
        end
    end,
}

OverworldAbility.defs = A

-- ---------------------------------------------------------------------------
-- Resolution + dispatch
-- ---------------------------------------------------------------------------

-- The ability id a character carries: the live field if instantiate copied it, else the blueprint's.
local function abilityId(char)
    if not char then return nil end
    if char.overworldAbility then return char.overworldAbility end
    local def = char.id and Character.defs[char.id]
    return def and def.overworldAbility or nil
end

-- Fire `event` for every party member whose overworld ability defines a hook for it. `ctx.state` is the
-- per-run scratch (game.abilityState); each ability's bucket is namespaced under the character's id.
function OverworldAbility.dispatch(event, ctx)
    local party = ctx.party or (ctx.player and ctx.player.roster) or {}
    ctx.state = ctx.state or {}
    for _, char in ipairs(party) do
        local h = A[abilityId(char)]
        if h and h[event] then
            local key = char.id or tostring(char)
            ctx.state[key] = ctx.state[key] or {}
            h[event](char, ctx.state[key], ctx)
        end
    end
end

-- The extra fog radius the party earns from an ability (Gyeom's Ledger). Read by states/game.lua when it
-- builds the map's vision. Returns the largest bonus in the party (they don't stack).
function OverworldAbility.visionBonus(player)
    local best = 0
    for _, char in ipairs((player and player.roster) or {}) do
        if abilityId(char) == "ledger" then best = math.max(best, 1) end
    end
    return best
end

-- Player-facing name + one-line description per ability, for the hover tooltip on the party strip and
-- anywhere else the passive needs to explain itself. Keyed by ability id.
local INFO = {
    vigil = { name = "Vigil",
        blurb = "Clear a fight with no one downed to bank a Vigil. The front line opens the next fight "
            .. "with a health buffer -- one per Vigil. A casualty breaks the streak." },
    held_swing = { name = "Held Swing",
        blurb = "The more new ground Saber covers between fights, the more she heals herself on her next "
            .. "win. Patience, not haste -- pacing in place mints nothing." },
    kept_trust = { name = "Kept Trust",
        blurb = "After every fight, Amana heals the most-wounded ally. Given freely, kept from no one." },
    aqua_vitae = { name = "Aqua Vitae",
        blurb = "Each side-fight won distils a dose. On reaching the boss, every dose is poured into "
            .. "the whole party at once." },
    forage = { name = "Forage",
        blurb = "Kaya turns up a little gold from newly explored tiles -- dead-ends most of all -- up "
            .. "to a cap each run, and senses nearby Reliquaries through the fog." },
    ledger = { name = "Ledger",
        blurb = "Gyeom reads the ground: +1 vision, and after three fights the fog lifts off the "
            .. "objective and every Reliquary on the board." },
    jubilee = { name = "Jubilee",
        blurb = "Clem takes the collector's craft and runs it backward: her cut is minted and added on "
            .. "top of every side-fight win." },
}

-- The { name, blurb } for `char`'s overworld ability, or nil if it has none.
function OverworldAbility.info(char)
    return INFO[abilityId(char)]
end

-- The raw banked quantity for `char`'s ability this run (given its scratch bucket), or nil if nothing
-- is pending. Drives the little counter on the party-strip badge. (Amana/Clem bank nothing -- they fire
-- instantly -- so they never show a counter.)
function OverworldAbility.bankedCount(char, bucket)
    if not bucket then return nil end
    local id = abilityId(char)
    local n
    if id == "vigil" then n = bucket.vigils
    elseif id == "held_swing" then n = bucket.steps
    elseif id == "aqua_vitae" then n = bucket.doses
    elseif id == "forage" then n = bucket.gained
    elseif id == "ledger" then n = (not bucket.revealed) and bucket.study or nil end
    return (n and n > 0) and n or nil
end

-- A short label for what `char`'s ability has banked this run (given its scratch bucket), or nil if
-- nothing is pending. The party panel shows it so the player can see what is building toward a payoff.
function OverworldAbility.bankedSummary(char, bucket)
    if not bucket then return nil end
    local id = abilityId(char)
    if id == "vigil" and (bucket.vigils or 0) > 0 then return "Vigil x" .. bucket.vigils end
    if id == "held_swing" and (bucket.steps or 0) > 0 then return "Patience: " .. bucket.steps .. " paces" end
    if id == "aqua_vitae" and (bucket.doses or 0) > 0 then
        return bucket.doses .. " dose" .. (bucket.doses == 1 and "" or "s")
    end
    if id == "forage" and (bucket.gained or 0) > 0 then return "Foraged " .. bucket.gained .. "g" end
    if id == "ledger" then
        if bucket.revealed then return "Quarry read" end
        if (bucket.study or 0) > 0 then return "Study " .. bucket.study .. "/3" end
    end
    return nil
end

return OverworldAbility
