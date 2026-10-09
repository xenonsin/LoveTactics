-- THE HOLLOW CROWN: the bottom of the rift, and the last fight of the game ("The Crown's Bestiary", slice D; every
-- line below approved over rounds 3-4 of the review page). The First Archon. The seven wants were all its own, and
-- seven people carried them off: the generals the company killed on the way down. What sits on the throne is hollow.
-- It has no sin left, so it does what a hollow thing does: it reaches for the rules the company already beat, one
-- floor at a time, and then for the company itself.
--
-- EVERY PHASE ASKS FOR A LESSON THE GAME ALREADY TAUGHT, so the fight is the exam and not a new set of rules. Each
-- rule below is somebody else's mechanic, called by its own name.
--
--   1 THE COURT CONVENES  It sits on its throne behind its court. While any Archon Warden holds still within 2 of the
--                         throne it takes no damage at all (ArchonCourt.holdingWardenNear, read in
--                         Status.immuneToDamage). Every fallen Archon's wisp walks to the throne instead of its body
--                         (Spirit's `wispGoal`), and each one that arrives (`onWispTaken`) heals it 10%. The phase
--                         ends when the court is down -- every Archon of its side, wisps included.
--   2 THE SEVEN WANTS     It rises. Each of its turns it shows one want as an Omen badge over its head and acts it
--                         the turn after: Swallowed, Charm, Gilded, Enraged, the Fairest's own ability, Drowsy, Magic
--                         Denied. Seven, in an order dealt off the fight's own roll, each once. Ends at half health.
--   3 THE PIT OPENS       It steps off the throne and walks. Each of its turns a ring of tiles at the board's edge is
--                         marked (hazard_crumbling_edge) and the ring marked the turn before falls: a body on it drops
--                         into the Pit, Downed, and Pit Locusts climb out. It hunts the body with the fewest open
--                         tiles around it (models/ai.lua's `hemmed`).
--   4 THE LAST HOUR       At a quarter health a count of 6 appears (status_last_hour). Each of its turns the count
--                         drops and it raises one Seal -- Immune: Slash, Pierce, Impact, Fire, Ice, Lightning, then
--                         Holy. A turn that opens on 0 swallows the board: every body still standing takes damage
--                         equal to its max health.
--
-- THE THRONE IS THE BODY. A transform keeps a body's footprint, so the throne is not a second unit the Crown sits
-- on: the Crown IS 3x3 for phases 1 and 2, seated at the far edge (Desidia.seat, built for a face that size) and
-- Enthroned (status_enthroned: it cannot move and nothing moves it). At half health it shrinks to the throne's
-- centre tile and walks -- the shrink the Gorged Vampire already does when it bursts (models/gorged.lua).
--
-- A STAGE, NOT A REFLEX. Every phase change fires on its threshold, in the dispatch that crossed it (the court's
-- last death, the blow past half or a quarter), never deferred to a turn the company could stun away. What waits for
-- the Crown's own turn is what the approved text says waits: a want is ACTED the turn after its omen, a marked ring
-- FALLS the turn after it was marked, and the count drops on its turn.
--
-- Pure logic, headless-safe. Combat, Status, Spirit and the rest are reached lazily: combat.lua reaches this module
-- from Status.immuneToDamage.

local HollowCrown = {}

HollowCrown.WANTS = { "gluttony", "lust", "greed", "wrath", "envy", "sloth", "pride" }
HollowCrown.WANT_NAMES = {
    gluttony = "Gluttony", lust = "Lust", greed = "Greed", wrath = "Wrath", envy = "Envy", sloth = "Sloth",
    pride = "Pride",
}
HollowCrown.SEALS = { "slash", "pierce", "impact", "fire", "ice", "lightning", "holy" }

HollowCrown.ENTHRONED = "status_enthroned"
HollowCrown.LAST_HOUR = "status_last_hour"
HollowCrown.EDGE = "hazard_crumbling_edge"
HollowCrown.LOCUST = "character_pit_locust"

HollowCrown.THRONE_REACH = 2   -- a Warden holding within this of the throne keeps the Crown whole (phase 1)
HollowCrown.WISP_HEAL = 0.10   -- of its max health, per wisp the throne takes
HollowCrown.HALF = 0.5         -- the Seven Wants end here
HollowCrown.QUARTER = 0.25     -- and the Pit closes here
HollowCrown.FREE_SHARE = 0.10  -- of its max health, dealt while it holds a body, lets the body out
HollowCrown.WRATH_STEP = 2     -- damage each wound adds to its next blow while Enraged
HollowCrown.GILDED_BODIES = 2
HollowCrown.COUNT = 6
HollowCrown.LOCUSTS_PER_RING = 2
HollowCrown.FOREVER = 9999

local function C() return require("models.combat") end
local function S() return require("models.status") end
local function T() return require("models.status").TICKS_PER_TURN end

local function name(u) return (u and u.char and u.char.name) or "The Crown" end

local function state(unit)
    unit.hollowCrown = unit.hollowCrown or { phase = 1, deck = {}, lastUsed = {}, swallowDealt = 0, seals = 0,
        ring = 0, edges = {} }
    return unit.hollowCrown
end
HollowCrown.state = state

function HollowCrown.phase(unit)
    return unit and unit.hollowCrown and unit.hollowCrown.phase or nil
end

local function fraction(unit)
    local hp = unit.char.stats.health
    if not hp.max or hp.max <= 0 then return 1 end
    return (hp.current or 0) / hp.max
end

local function onBoard(u)
    return u and u.alive and not C().isOffTile(u) and not u.timeless
end

local function foes(combat, crown)
    local out = {}
    for _, u in ipairs(combat.units or {}) do
        if onBoard(u) and u.side ~= crown.side then out[#out + 1] = u end
    end
    return out
end

-- The nearest of `list` to the Crown, ties to board order (so a seeded fight answers the same body).
local function nearest(crown, list)
    local best, bestD
    for _, u in ipairs(list) do
        local d = C().unitGap(crown, u)
        if not bestD or d < bestD then best, bestD = u, d end
    end
    return best
end

-- ------------------------------------------------------------------------------------- phase 1: the court

-- THE COURT'S WARD, read by Status.immuneToDamage beside the other wards: in phase 1, a holding Warden within 2 of
-- the throne voids the blow. A named marker, so the log and the hover say why.
local COURT_WARD = { id = "the_court_convenes", name = "The Court Convenes" }

function HollowCrown.ward(unit)
    local st = unit and unit.hollowCrown
    if not (st and st.phase == 1 and unit.combat) then return nil end
    if require("models.archon_court").holdingWardenNear(unit.combat, unit, HollowCrown.THRONE_REACH) then
        return COURT_WARD
    end
    return nil
end

-- Is any of its court still on the board? Every Archon of its side but itself, a walking wisp included -- a wisp is
-- an Archon, and one still walking to the throne is the court not yet down.
function HollowCrown.courtStanding(combat, crown)
    local Court = require("models.archon_court")
    for _, u in ipairs(combat.units or {}) do
        if u ~= crown and u.alive and u.side == crown.side and Court.isArchon(u) then return true end
    end
    return false
end

-- Turn every walking wisp of its side that has no living goal toward the throne. Asked whenever a wisp may have
-- been thrown (a death) and at every turn's edge, the Duke's own cadence (ArchonCourt.claimWisps).
function HollowCrown.claimWisps(combat, crown)
    if not (combat and crown and crown.alive) or HollowCrown.phase(crown) ~= 1 then return end
    for _, w in ipairs(combat.units or {}) do
        if w.alive and w.wispOf and w.side == crown.side and not (w.wispGoal and w.wispGoal.alive) then
            w.wispGoal = crown
            C().logEvent(combat, "status", "The wisp turns toward the throne.", { w, crown })
        end
    end
end

-- A wisp arrived at the throne (Spirit.tryArrive fires `onWispTaken`): the body it left stays down, and the Crown
-- heals a tenth of its health.
function HollowCrown.takeWisp(combat, crown)
    if not (combat and crown and crown.alive) then return 0 end
    local amount = math.max(1, math.floor(C().unreservedMax(crown.char, "health") * HollowCrown.WISP_HEAL + 0.5))
    local healed = C().applyHeal(combat, crown, amount) or 0
    C().logEvent(combat, "action", string.format("%s takes the wisp in.", name(crown)), crown)
    return healed
end

-- ------------------------------------------------------------------------------------ phase 2: the wants

-- The omen badge each want shows a turn ahead (data/status/status_omen_*.lua).
function HollowCrown.omenStatus(want) return "status_omen_" .. want end

-- A fresh deck of the seven, shuffled off the fight's own roll (Combat.roll: the arena-seeded generator), so a
-- replayed fight deals the same order. Fisher-Yates.
function HollowCrown.shuffle(combat)
    local deck = {}
    for i, w in ipairs(HollowCrown.WANTS) do deck[i] = w end
    for i = #deck, 2, -1 do
        local j = C().roll(combat, i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

-- SHOW THE NEXT WANT. Seven, each once; a deck that runs out before half health is dealt again.
function HollowCrown.showOmen(combat, crown)
    local st = state(crown)
    if #st.deck == 0 then st.deck = HollowCrown.shuffle(combat) end
    local want = table.remove(st.deck, 1)
    st.omen = want
    S().apply(combat, crown, HollowCrown.omenStatus(want), { applier = crown })
    -- Sloth measures who stood still from the moment its omen goes up (Desidia's Drowse, read off her snapshot).
    if want == "sloth" then require("models.desidia").snapshot(combat, crown) end
    C().logEvent(combat, "action", string.format("%s shows an omen: %s.", name(crown),
        HollowCrown.WANT_NAMES[want]), crown)
    return want
end

local function clearOmen(combat, crown)
    local st = state(crown)
    if st.omen then S().remove(combat, crown, HollowCrown.omenStatus(st.omen)) end
    st.omen = nil
end

-- Whoever hits hardest: the larger of a body's Damage and Magic Damage, ties to the nearer.
local function hardestHitter(combat, crown)
    local best, bestN, bestD
    for _, u in ipairs(foes(combat, crown)) do
        local n = math.max(C().flatStat(u, "damage"), C().flatStat(u, "magicDamage"))
        local d = C().unitGap(crown, u)
        if not bestN or n > bestN or (n == bestN and d < bestD) then best, bestN, bestD = u, n, d end
    end
    return best
end

local ACT = {}

-- GLUTTONY: Swallows the nearest body. The tenth of its health dealt while it holds one is counted in
-- HollowCrown.damaged; the Gullet on its organ lets the body out on a stun or its death.
function ACT.gluttony(combat, crown)
    local list = {}
    for _, u in ipairs(foes(combat, crown)) do
        if C().canSwallow(combat, crown, u) then list[#list + 1] = u end
    end
    local body = nearest(crown, list)
    if not body then return nil end
    state(crown).swallowDealt = 0
    S().apply(combat, body, "status_swallowed", { applier = crown })
    return body
end

-- LUST: Charms the hardest hitter, for a turn -- Charm's own length, which its header sizes as long enough for the
-- victim to actually take one turn on the Crown's side. A clock of exactly one turn's ticks could run out before the
-- charmed body ever came round, and a charm that never acts is not one.
function ACT.lust(combat, crown)
    local body = hardestHitter(combat, crown)
    if body then S().apply(combat, body, "status_charm", { applier = crown }) end
    return body
end

-- GREED: Gilds the two nearest bodies. This gilding breaks under impact (status_gilded's `breaksOnImpact`).
function ACT.greed(combat, crown)
    local pool = foes(combat, crown)
    local out = {}
    for _ = 1, HollowCrown.GILDED_BODIES do
        local body = nearest(crown, pool)
        if not body then break end
        for i, u in ipairs(pool) do if u == body then table.remove(pool, i) break end end
        local s = S().apply(combat, body, "status_gilded", { applier = crown })
        if s then s.breaksOnImpact = true end
        out[#out + 1] = body
    end
    return out
end

-- WRATH: Enraged. Every wound from here sharpens its next blow (HollowCrown.damaged banks it; the turn it next acts
-- spends it).
function ACT.wrath(combat, crown)
    local st = state(crown)
    -- Already Enraged (a second deck dealt Wrath before the first rage was spent): the bank it holds stands.
    if st.wrath then return crown end
    st.wrath = { bank = 0 }
    S().apply(combat, crown, "status_enraged", { magnitude = 0, applier = crown })
    return crown
end

-- ENVY: names the Fairest (models/fairest.lua) and turns the last ability it used back on it.
function ACT.envy(combat, crown)
    local fairest = require("models.fairest").across(combat, crown)
    if not fairest then return nil end
    C().logEvent(combat, "action", string.format("%s names %s the Fairest.", name(crown), name(fairest)),
        { crown, fairest })
    local item = state(crown).lastUsed[fairest]
    local ab = item and item.activeAbility
    if not ab then
        C().logEvent(combat, "status", string.format("%s has done nothing worth wanting.", name(fairest)), fairest)
        return fairest
    end
    -- At the Fairest when the working is aimed at a foe or does damage; on itself when it is a blessing.
    local atFoe = ab.target == "enemy" or (ab.target == "tile" and ab.damage ~= nil)
    local tx, ty = crown.x, crown.y
    if atFoe then tx, ty = fairest.x, fairest.y end
    C().logEvent(combat, "action", string.format("%s copies %s.", name(crown), item.name or "it"), crown)
    -- Some workings reach for helpers only a full cast builds; a copy that cannot be held is let go, not crashed.
    local ok = pcall(C().strikeWith, combat, crown, item, tx, ty)
    if not ok then
        C().logEvent(combat, "status", string.format("%s cannot hold %s.", name(crown), item.name or "it"), crown)
    end
    return fairest
end

-- SLOTH: every body that did not move since the omen went up grows Drowsy (Desidia's Drowse, either side, never it).
function ACT.sloth(combat, crown)
    return require("models.desidia").drowse(combat, crown)
end

-- PRIDE: Magic Denied on the last body of the company to cast a magical working, for three turns.
function ACT.pride(combat, crown)
    local body = state(crown).lastCaster
    if not (body and body.alive and body.side ~= crown.side) then return nil end
    S().apply(combat, body, "status_magic_denied", { applier = crown, duration = 3 * T() })
    return body
end

function HollowCrown.act(combat, crown, want)
    local fn = ACT[want]
    if not (fn and crown.alive) then return nil end
    C().logEvent(combat, "action", string.format("%s acts its want: %s.", name(crown), HollowCrown.WANT_NAMES[want]),
        crown)
    return fn(combat, crown)
end

-- Remember what everybody used (Envy reads the Fairest's) and who last worked magic (Pride's mark). onAnyCast.
function HollowCrown.saw(combat, crown, caster, item)
    if not (crown and caster and item and item.activeAbility) then return end
    local st = state(crown)
    if item.type == "weapon" or item.type == "ability" then st.lastUsed[caster] = item end
    if caster.side ~= crown.side and C().isMagicItem(item) then st.lastCaster = caster end
end

-- --------------------------------------------------------------------------------------- phase 3: the pit

local function dims(combat)
    local a = combat.arena or {}
    local rows = a.rows or (a.tiles and #a.tiles) or 0
    local cols = a.cols or (a.tiles and a.tiles[1] and #a.tiles[1]) or 0
    return cols, rows
end

-- How deep a tile sits from the board's edge: 0 on the outer ring.
local function depth(cols, rows, x, y)
    return math.min(x - 1, y - 1, cols - x, rows - y)
end

-- The walkable tiles of ring `k` (1 = the outermost).
function HollowCrown.ringTiles(combat, k)
    local cols, rows = dims(combat)
    local tiles = combat.arena and combat.arena.tiles
    local out = {}
    for y = 1, rows do
        for x = 1, cols do
            local cell = tiles and tiles[y] and tiles[y][x]
            if cell and cell.walkable and depth(cols, rows, x, y) == k - 1 then out[#out + 1] = { x = x, y = y } end
        end
    end
    return out
end

-- The deepest ring the Pit may take: it stops short of the board's heart, so there is always ground to stand on.
function HollowCrown.maxRing(combat)
    local cols, rows = dims(combat)
    return math.max(0, math.floor(math.min(cols, rows) / 2) - 1)
end

-- MARK THE NEXT RING: the next one in with any ground left on it. Returns its tiles, or nil when the Pit has gone as
-- far as it goes.
function HollowCrown.markRing(combat, crown)
    local st = state(crown)
    local Hazard = require("models.hazard")
    local k = st.ring + 1
    while k <= HollowCrown.maxRing(combat) do
        local tiles = HollowCrown.ringTiles(combat, k)
        if #tiles > 0 then
            st.ring = k
            st.marked = tiles
            st.edges = {}
            for _, t in ipairs(tiles) do
                local h = Hazard.place(combat, t.x, t.y, HollowCrown.EDGE, { duration = HollowCrown.FOREVER })
                if h then st.edges[#st.edges + 1] = h end
            end
            C().logEvent(combat, "action", "The edge of the board begins to crumble.", crown)
            return tiles
        end
        k = k + 1
    end
    st.marked = nil
    return nil
end

local function liftEdges(combat, crown)
    local st = state(crown)
    local Hazard = require("models.hazard")
    for _, h in ipairs(st.edges or {}) do Hazard.consume(combat, h) end
    st.edges = {}
end

-- The Pit's own ground: the cave's lava, the same rewrite Combat.openChasm makes, so a fallen ring is impassable to
-- every foot and crossed by a flier, and no line of sight is cut by it.
local function toPit(combat, x, y)
    local Hazard = require("models.hazard")
    local cell = combat.arena.tiles[y][x]
    local lava = require("models.terrain").get("lava")
    cell.type = "lava"
    cell.moveCost = lava.moveCost
    cell.walkable = lava.walkable
    cell.sightCost = lava.sightCost or 0
    cell.bonus = lava.bonus
    cell.tags = lava.tags
    cell.swim, cell.drowns = nil, nil
    local zones = {}
    for _, z in ipairs(Hazard.allAt(combat, x, y) or {}) do zones[#zones + 1] = z end
    for _, z in ipairs(zones) do Hazard.consume(combat, z) end
end

-- THE MARKED RING FALLS. A body on it drops into the Pit and is Downed -- laid down with the ordinary revive window
-- (Combat.fell, `denyRevival = false`), so a company can still reach it. The Crown and a flier keep their tiles,
-- and the ground under them stays: nothing is left standing on ground nothing can stand on. Then the locusts climb
-- out, onto the inside edge. Returns the bodies that fell.
function HollowCrown.fallRing(combat, crown)
    local st = state(crown)
    local tiles = st.marked
    if not tiles then return {} end
    st.marked = nil
    liftEdges(combat, crown)
    local Combat = C()
    local fell, seen = {}, {}
    for _, t in ipairs(tiles) do
        local u = Combat.unitAt(combat, t.x, t.y)
        if u and u.alive and u ~= crown and not seen[u] and not Combat.isFlying(u) and not u.char.boss then
            seen[u] = true
            Combat.logEvent(combat, "action", string.format("%s drops into the Pit.", name(u)), u)
            Combat.fell(combat, u, { denyRevival = false })
            fell[#fell + 1] = u
        end
    end
    local dropped = 0
    for _, t in ipairs(tiles) do
        local stander = Combat.unitAt(combat, t.x, t.y)
        if not stander then
            toPit(combat, t.x, t.y)
            dropped = dropped + 1
        end
    end
    if dropped > 0 then
        Combat.logEvent(combat, "action", string.format("The edge falls into the Pit: %d tiles.", dropped), crown)
    end
    HollowCrown.locusts(combat, crown, st.ring)
    return fell
end

-- PIT LOCUSTS CLIMB OUT of the ring that just fell, onto the open tiles of the ring inside it: the first in reading
-- order, then the one farthest from it, so the pair comes up on two sides of the board. Held inside the arena's
-- enemy cap (Arena.DEFAULT_ENEMY_CAP), so the swarm never outgrows the stair it stands on. Sustained by the Crown:
-- they go when it falls, which keeps the stair's `assassinate` honest.
function HollowCrown.locusts(combat, crown, ring)
    local Combat = C()
    local cap = require("models.arena").DEFAULT_ENEMY_CAP
    local standing = 0
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side == crown.side then standing = standing + 1 end
    end
    local open = {}
    for _, t in ipairs(HollowCrown.ringTiles(combat, (ring or 0) + 1)) do
        if Combat.footprintFree(combat, 1, 1, t.x, t.y) then open[#open + 1] = t end
    end
    local picks = {}
    if open[1] then
        picks[1] = open[1]
        local far, farD
        for i = 2, #open do
            local d = math.abs(open[i].x - open[1].x) + math.abs(open[i].y - open[1].y)
            if not farD or d > farD then far, farD = open[i], d end
        end
        picks[2] = far
    end
    local made = {}
    local Summon = require("models.summon")
    for i = 1, HollowCrown.LOCUSTS_PER_RING do
        local t = picks[i]
        if t and standing < cap then
            local u = Summon.spawn(combat, crown, HollowCrown.LOCUST, t.x, t.y, { announce = false })
            if u then
                made[#made + 1] = u
                standing = standing + 1
            end
        end
    end
    if #made > 0 then
        Combat.logEvent(combat, "action", "Pit Locusts climb out of the Pit.", made)
    end
    return made
end

-- How many open tiles stand around a body (its eight neighbours, off its footprint): walkable, and with nobody and
-- nothing on them. What the Crown hunts by in phase 3 (models/ai.lua's `hemmed`): the body with the fewest.
function HollowCrown.openAround(combat, u)
    local Combat = C()
    local tiles = combat and combat.arena and combat.arena.tiles
    if not (tiles and u) then return 0 end
    local w, h = u.w or 1, u.h or 1
    local n = 0
    for y = u.y - 1, u.y + h do
        for x = u.x - 1, u.x + w do
            local inside = x >= u.x and x <= u.x + w - 1 and y >= u.y and y <= u.y + h - 1
            local cell = tiles[y] and tiles[y][x]
            if not inside and cell and cell.walkable and not Combat.unitAt(combat, x, y)
                and not Combat.objectAt(combat, x, y) then
                n = n + 1
            end
        end
    end
    return n
end

-- ----------------------------------------------------------------------------------- phase 4: the last hour

-- RAISE THE NEXT SEAL, and hold up every seal already raised. A seal is the existing Immune status for its kind
-- (Immune: Slash and kin), refreshed each of its turns rather than laid forever, so the badge reads a real clock.
function HollowCrown.raiseSeal(combat, crown)
    local st = state(crown)
    if st.seals < #HollowCrown.SEALS then
        st.seals = st.seals + 1
        C().logEvent(combat, "action", string.format("%s raises a Seal against %s.", name(crown),
            HollowCrown.SEALS[st.seals]), crown)
    end
    for i = 1, st.seals do
        S().apply(combat, crown, "status_immune_" .. HollowCrown.SEALS[i], { duration = 4 * T(), applier = crown })
    end
    return HollowCrown.SEALS[st.seals]
end

local function showCount(combat, crown)
    local st = state(crown)
    local s = S().get(crown, HollowCrown.LAST_HOUR)
    if s then s.magnitude = st.count else
        S().apply(combat, crown, HollowCrown.LAST_HOUR, { magnitude = st.count, applier = crown })
    end
end

-- THE BOARD IS SWALLOWED: every body still standing but the Crown takes damage equal to its max health. Once.
function HollowCrown.swallowBoard(combat, crown)
    local st = state(crown)
    if st.swallowed then return end
    st.swallowed = true
    local Combat = C()
    Combat.logEvent(combat, "action", string.format("The count runs out, and %s swallows the board.", name(crown)),
        crown)
    local victims = {}
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u ~= crown then victims[#victims + 1] = u end
    end
    for _, u in ipairs(victims) do
        if u.alive then
            Combat.dealFlatDamage(combat, u, Combat.unreservedMax(u.char, "health"), {}, "The Last Hour", crown,
                { raw = true })
        end
    end
end

-- ------------------------------------------------------------------------------------------- the phases

local function enterPhase2(combat, crown)
    local st = state(crown)
    st.phase = 2
    local throne = S().get(crown, HollowCrown.ENTHRONED)
    if throne then throne.court = false end
    C().logEvent(combat, "action", string.format("The court is down. %s rises from its throne.", name(crown)), crown)
    st.deck = HollowCrown.shuffle(combat)
    HollowCrown.showOmen(combat, crown)
end

-- OFF THE THRONE: the 3x3 body becomes the 1x1 body at its centre, Enthroned comes off, and it walks.
function HollowCrown.stand(combat, crown)
    S().remove(combat, crown, HollowCrown.ENTHRONED)
    local w, h = crown.w or 1, crown.h or 1
    if w > 1 or h > 1 then
        local cx, cy = crown.x + math.floor((w - 1) / 2), crown.y + math.floor((h - 1) / 2)
        crown.w, crown.h = 1, 1
        crown.char.footprint = { w = 1, h = 1 }
        crown.x, crown.y = cx, cy
        C().stampField(combat, crown)
    end
    C().logEvent(combat, "action", string.format("%s steps down from the throne.", name(crown)), crown)
end

local function enterPhase3(combat, crown)
    local st = state(crown)
    st.phase = 3
    clearOmen(combat, crown)
    C().logEvent(combat, "action", "At half its health, the bottom of the world gives way.", crown)
    HollowCrown.stand(combat, crown)
    HollowCrown.markRing(combat, crown)
end

local function enterPhase4(combat, crown)
    local st = state(crown)
    st.phase = 4
    st.count = HollowCrown.COUNT
    C().logEvent(combat, "action", string.format("A count of %d appears over the board.", st.count), crown)
    showCount(combat, crown)
    HollowCrown.raiseSeal(combat, crown)
end

-- WALK THE PHASES FORWARD as far as the board allows. One call can cross several (a blow past half and a quarter at
-- once), and every crossing runs in order.
function HollowCrown.advance(combat, crown)
    if not (combat and crown and crown.alive) then return end
    local st = state(crown)
    local moved = true
    while moved and crown.alive do
        moved = false
        if st.phase == 1 and not HollowCrown.courtStanding(combat, crown) then
            enterPhase2(combat, crown); moved = true
        elseif st.phase == 2 and fraction(crown) <= HollowCrown.HALF then
            enterPhase3(combat, crown); moved = true
        elseif st.phase == 3 and fraction(crown) <= HollowCrown.QUARTER then
            enterPhase4(combat, crown); moved = true
        end
    end
end

-- ------------------------------------------------------------------------------------------- the hooks

-- THE BELL: seated at the far edge, Enthroned, its court around it. A Crown with no court at all (a bare board, the
-- breach) is down to its wants from the first beat.
function HollowCrown.open(combat, crown)
    local st = state(crown)
    st.phase = 1
    require("models.desidia").seat(combat, crown)
    S().apply(combat, crown, HollowCrown.ENTHRONED, { applier = crown })
    local throne = S().get(crown, HollowCrown.ENTHRONED)
    if throne then throne.court = true end
    HollowCrown.claimWisps(combat, crown)
    HollowCrown.advance(combat, crown)
end

-- ITS OWN TURN OPENS: what waited a turn happens now.
function HollowCrown.turnStart(combat, crown)
    local st = state(crown)
    HollowCrown.claimWisps(combat, crown)
    HollowCrown.advance(combat, crown)
    if not crown.alive then return end
    if st.phase == 2 then
        local want = st.omen
        if want then
            clearOmen(combat, crown)
            HollowCrown.act(combat, crown, want)
        end
        if crown.alive and st.phase == 2 then HollowCrown.showOmen(combat, crown) end
    elseif st.phase == 3 then
        HollowCrown.fallRing(combat, crown)
        if crown.alive and st.phase == 3 then HollowCrown.markRing(combat, crown) end
    elseif st.phase == 4 then
        -- A ring marked before the hour began still falls: the board was promised it.
        if st.marked then HollowCrown.fallRing(combat, crown) end
        if (st.count or 0) <= 0 then
            HollowCrown.swallowBoard(combat, crown)
        else
            st.count = st.count - 1
            showCount(combat, crown)
            HollowCrown.raiseSeal(combat, crown)
        end
    end
    -- Wrath's bank is spent on the blow of the turn that opens with something in it.
    if st.wrath and st.wrath.bank > 0 then st.wrath.spend = true end
end

-- ITS OWN TURN ENDS: a sharpened blow has been thrown, so the bank goes.
function HollowCrown.turnEnd(combat, crown)
    local st = state(crown)
    local wrath = st.wrath
    if wrath and wrath.spend then
        crown.bonus = crown.bonus or {}
        crown.bonus.damage = (crown.bonus.damage or 0) - wrath.bank
        S().remove(combat, crown, "status_enraged")
        st.wrath = nil
    end
end

-- A WOUND LANDED AND IT STOOD. The body it is holding comes out once a tenth of its health has been dealt; a wound
-- while Enraged sharpens the next blow; and the bar may have crossed a phase.
function HollowCrown.damaged(combat, crown, amount)
    local st = state(crown)
    amount = amount or 0
    local Combat = C()
    local held = Combat.swallowedIn(combat, crown)
    if held and amount > 0 then
        st.swallowDealt = (st.swallowDealt or 0) + amount
        if st.swallowDealt >= Combat.unreservedMax(crown.char, "health") * HollowCrown.FREE_SHARE then
            S().remove(combat, held, "status_swallowed")
            st.swallowDealt = 0
        end
    end
    if st.wrath and amount > 0 and not st.wrath.spend then
        st.wrath.bank = st.wrath.bank + HollowCrown.WRATH_STEP
        crown.bonus = crown.bonus or {}
        crown.bonus.damage = (crown.bonus.damage or 0) + HollowCrown.WRATH_STEP
        S().apply(combat, crown, "status_enraged", { magnitude = st.wrath.bank, applier = crown })
    end
    HollowCrown.advance(combat, crown)
end

function HollowCrown.onDeath(combat, crown)
    liftEdges(combat, crown)
    state(crown).marked = nil
end

return HollowCrown
