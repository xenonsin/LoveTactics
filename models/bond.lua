-- BONDS: what fighting beside the avatar builds, and what it is worth. Fire Emblem's supports with the
-- avatar as the only hub (approved 2026-10-25 over three review rounds; the page is
-- https://claude.ai/artifact/7eC6FDAmuZxgouBW67QRZ7 and its readouts https://claude.ai/artifact/3395bru9XfLnZDPEe2JKXX).
--
-- WHY THE AVATAR IS THE HUB. Hires can unlock classes and the avatar's fall costs nothing a companion's
-- does not, so nothing set the player's own body apart from a stranger off the Lodge board. Fire Emblem
-- and FFT do it with a seat that is never empty and a system only the lead runs. This is that system:
-- only pairs that include the avatar exist, and the avatar always walks down (Descent.party).
--
-- A BOND IS A PAIR'S POINTS AND ITS RANK. `player.avatarBonds[charId] = { points, rank, rankRun }`. Points come
-- from ACTING TOGETHER, Fire Emblem's way (2026-11-07): one per BOND DEED (Combat.bondDeed) -- a strike
-- thrown with the other standing beside you, a heal given to the other, a blow taken that was meant for
-- the other, the foe that last hit the other felled. Each deed pops over the partner's head as it lands
-- and is banked on a win (Bond.settle), at most DEED_CAP a fight. (Until then a pair also earned a point
-- for ending the fight within RANGE, which nobody saw happen.) The rank follows the points, one rank a
-- won fight at most.
--
-- PACED TO ONE RUN: S AROUND FLOOR 13 (2026-11-13). The ranks used to rise at most once a run against
-- thresholds of 3 / 8 / 16 -- a bar that filled in two fights, and a cap that runs made cheap, since a
-- dip to floor one and back is a run. Now the points alone pace it, against what a run deals: about
-- 4.1 fights a floor (Descent.FLOOR_FIGHTS), and a partner earned 1.0 deeds a won fight under the run
-- simulator's autobattle (`. run-sim`, 4 saves x 3 runs, 271 partner-fights) -- which does not seek
-- its partner out; a pair kept together on purpose lands nearer 1.5. At ~1.25 that is about five
-- points a floor, so C comes on floor 2, B on 5, A on 9 and S on 13. `rankRun` is still stamped on a
-- rise: it is what tells an old save's seeded rank from an earned one (Bond.entry).
--
-- WHAT A RANK GIVES:
--   D           nothing. It is a seed rank only (below), and nobody earns into it: a first rise is to C.
--   C and up    a bonded ally within RANGE of the avatar gains Hit and Avoid (Bond.HIT) -- accuracy only,
--               because the avatar is Balance.REFERENCE and a damage bonus would move every enemy band;
--   B           Trade Places and Teamwork, the avatar's two once-a-fight verbs (models/combat.lua);
--   A           Follow-up (an adjacent A partner adds a blow when the avatar strikes, once a round) and
--               Stand Firm (either partner falls, the other surges).
--   S           Follow-up FROM RANGE: the partner answers the avatar's blow from anywhere its weapon
--               reaches the foe, not only from beside it. The bow and the staff get their dual strike.
--
-- Rowan and Xin start at D -- the ties are older than the trade, so the list names them from the first
-- day, but every bonus is earned in play like anyone's (they started at B until 2026-11-03, which put
-- Teamwork on the first fight's bar before a bond had ever been built). Everyone else, the other five
-- companions included, starts at nothing. A hire's bond goes when the hire does (Bond.forget).
--
-- No love.graphics here: this loads under the headless runner (tests/bond_spec.lua).

local Bond = {}

Bond.AVATAR_ID = "character_avatar"

-- The ranks, lowest first. A pair below C has points and no rank -- or D, if START seeded it there.
-- Thresholds are cumulative points; see "PACED TO ONE RUN" above for where each lands.
Bond.RANKS = { "D", "C", "B", "A", "S" }
Bond.THRESHOLD = { D = 0, C = 10, B = 25, A = 45, S = 70 }

-- The accuracy a rank lends, on Hit when the partner swings and on Avoid when it is swung at. D lends none.
Bond.HIT = { C = 5, B = 10, A = 15, S = 20 }

-- How close to the avatar a partner has to stand for the Hit/Avoid bonus.
Bond.RANGE = 2

-- Bond deeds a pair can bank in one fight (Combat.bondDeed), so one long fight cannot fill a bar.
Bond.DEED_CAP = 3

-- Who starts bonded, and at what rank. Childhood friends; nobody else.
Bond.START = { character_rowan = "D", character_xin = "D" }

local INDEX = { D = 1, C = 2, B = 3, A = 4, S = 5 }

function Bond.rankIndex(rank) return INDEX[rank] or 0 end

-- Is this rank at least `atLeast`? Nil (no rank) is below everything.
function Bond.atLeast(rank, atLeast) return Bond.rankIndex(rank) >= Bond.rankIndex(atLeast) end

function Bond.isAvatar(charOrId)
    local id = type(charOrId) == "table" and charOrId.id or charOrId
    return id == Bond.AVATAR_ID
end

-- The pair's entry, seeded from START the first time it is asked for, so an old save and a new game agree
-- without a migration. Nil for the avatar itself (it has no bond with itself) and for no player.
function Bond.entry(player, charId)
    if not (player and charId) or Bond.isAvatar(charId) then return nil end
    player.avatarBonds = player.avatarBonds or {}
    local e = player.avatarBonds[charId]
    if not e then
        local start = Bond.START[charId]
        if not start then return nil end
        e = { points = Bond.THRESHOLD[start], rank = start }
        player.avatarBonds[charId] = e
    elseif Bond.START[charId] and e.rankRun == nil and Bond.rankIndex(e.rank) > Bond.rankIndex(Bond.START[charId]) then
        -- An old save's seed: a rank above today's START that no run ever raised (an earned rise always
        -- stamps rankRun) is the B the seed used to hand out. Re-seed it, keeping the points earned on top.
        local start = Bond.START[charId]
        e.points = Bond.THRESHOLD[start] + math.max(0, (e.points or 0) - Bond.THRESHOLD[e.rank])
        e.rank = start
    end
    return e
end

function Bond.rank(player, charId)
    local e = Bond.entry(player, charId)
    return e and e.rank or nil
end

function Bond.points(player, charId)
    local e = Bond.entry(player, charId)
    return e and e.points or 0
end

-- The rank after `rank`, or nil at S. No rank rises straight to C: D is only ever seeded, because a rise
-- into it would spend the run's one rise on a rank that gives nothing.
function Bond.nextRank(rank)
    if rank == nil then return "C" end
    return Bond.RANKS[Bond.rankIndex(rank) + 1]
end

-- Points still owed to the next rank, or nil at S.
function Bond.toNext(player, charId)
    local nxt = Bond.nextRank(Bond.rank(player, charId))
    if not nxt then return nil end
    return math.max(0, Bond.THRESHOLD[nxt] - Bond.points(player, charId))
end

-- Add `n` points to the pair and let the rank rise one step if the points reach the next threshold.
-- `run` is stamped on the rise (Bond.entry reads it to tell earned from seeded). Returns `from, to`
-- when it rose (from may be nil: a first rank), nothing otherwise.
function Bond.award(player, charId, n, run)
    if not (player and charId) or Bond.isAvatar(charId) or (n or 0) <= 0 then return nil end
    player.avatarBonds = player.avatarBonds or {}
    local e = Bond.entry(player, charId)
    if not e then
        e = { points = 0 }
        player.avatarBonds[charId] = e
    end
    e.points = e.points + n
    local nxt = Bond.nextRank(e.rank)
    if nxt and e.points >= Bond.THRESHOLD[nxt] then
        local from = e.rank
        e.rank, e.rankRun = nxt, run
        return from, nxt
    end
    return nil
end

-- Drop a pair for good: a hire dismissed, or a hire who fell on a wipe.
function Bond.forget(player, charId)
    if player and player.avatarBonds and charId then player.avatarBonds[charId] = nil end
end

-- Every bond the avatar holds, as { { id, rank, points, toNext } }, highest rank first then by id -- what
-- the Armory's BONDS list walks. Only bodies on the roster; a pair with no points and no rank is left out.
function Bond.list(player)
    local out = {}
    for _, char in ipairs((player and player.roster) or {}) do
        if not Bond.isAvatar(char) then
            local e = Bond.entry(player, char.id)
            if e and (e.rank or (e.points or 0) > 0) then
                out[#out + 1] = { id = char.id, char = char, rank = e.rank, points = e.points,
                                  toNext = Bond.toNext(player, char.id) }
            end
        end
    end
    table.sort(out, function(a, b)
        local ra, rb = Bond.rankIndex(a.rank), Bond.rankIndex(b.rank)
        if ra ~= rb then return ra > rb end
        if a.points ~= b.points then return a.points > b.points end
        return a.id < b.id
    end)
    return out
end

-- WHAT A FIGHT READS: the ranks as { [charId] = rank }, stamped on `combat.bonds` by the battle screen
-- right after Combat.new (combat has no player). Always a table -- an empty one still says "this fight
-- keeps a bond ledger", which is what lets a no-rank pair bank its first covering deeds.
function Bond.snapshot(player)
    local out = {}
    for _, char in ipairs((player and player.roster) or {}) do
        local rank = Bond.rank(player, char.id)
        if rank then out[char.id] = rank end
    end
    return out
end

-- The fight-only traits a body carries for its bond (Trait.attach): an A-rank (or S-rank) partner
-- follows up and stands firm; the avatar stands firm when it holds any such bond in this fight's snapshot.
function Bond.traitsFor(combat, unit)
    local ranks = combat and combat.bonds
    local char = unit and unit.char
    if not (ranks and char and char.id) or unit.side ~= "party" or unit.summoned then return {} end
    if Bond.isAvatar(char) then
        for _, rank in pairs(ranks) do
            if Bond.atLeast(rank, "A") then return { "trait_bond_stand_firm" } end
        end
        return {}
    end
    if Bond.atLeast(ranks[char.id], "A") then return { "trait_bond_follow_up", "trait_bond_stand_firm" } end
    return {}
end

-- The avatar's roster instance, or nil.
function Bond.avatarOf(player)
    for _, char in ipairs((player and player.roster) or {}) do
        if Bond.isAvatar(char) then return char end
    end
    return nil
end

-- THE SCENE A RISE PLAYS before its card: `conversation_bond_<who>_<rank>` (data/conversations/bond/),
-- e.g. conversation_bond_rowan_a. Seventeen of them, every line the author's: Rowan and Xin rise once (to
-- A), the other five companions three times. No S scene is written yet; an S rise shows its card alone. Nil for a hire -- hires never speak -- and for a pair with no
-- scene authored, so a missing file costs the scene and never the card.
function Bond.sceneId(charId, rank)
    local who = charId and charId:match("^character_([%w_]+)$")
    if not (who and rank) then return nil end
    return "conversation_bond_" .. who .. "_" .. rank:lower()
end

function Bond.sceneFor(rise)
    if not (rise and rise.char and rise.to) or rise.char.hire then return nil end
    local id = Bond.sceneId(rise.id or rise.char.id, rise.to)
    local defs = id and require("models.conversation").defs
    return (defs and defs[id]) and id or nil
end

-- THE RUN a rise is stamped against. `runsStarted` counts every descent begun, so it moves once a run.
function Bond.runOf(player) return (player and player.runsStarted) or 0 end

-- Board distance, the footprint-aware Manhattan gap every range and aura on the board measures
-- (Combat.unitGap): 1 is orthogonally adjacent.
function Bond.gap(a, b)
    if not (a and b and a.x and b.x) then return math.huge end
    return require("models.combat").unitGap(a, b)
end

-- SETTLE A WON FIGHT. `units` is the board's unit list; `deeds` is { [charId] = n } of bond deeds the
-- fight counted (Combat's bond ledger, each one already shown over the partner's head as it happened),
-- capped here at DEED_CAP. Deeds are the only source: there is no point for merely ending the fight
-- close, because Fire Emblem's supports grow from acting together and a point nobody saw land teaches
-- nothing. Returns the rises as { { id, char, from, to } } in roster order, for the bond card.
function Bond.settle(player, units, deeds, run)
    if not player then return {} end
    run = run or Bond.runOf(player)
    local earned = {}
    for _, u in ipairs(units or {}) do
        local char = u.char
        if char and char.id and not Bond.isAvatar(char) and u.side == "party" and not u.summoned then
            local n = math.min(Bond.DEED_CAP, (deeds and deeds[char.id]) or 0)
            if n > 0 then earned[char.id] = n end
        end
    end
    local rises = {}
    for _, char in ipairs(player.roster or {}) do
        local n = earned[char.id]
        if n then
            local from, to = Bond.award(player, char.id, n, run)
            if to then rises[#rises + 1] = { id = char.id, char = char, from = from, to = to } end
        end
    end
    return rises
end

return Bond
