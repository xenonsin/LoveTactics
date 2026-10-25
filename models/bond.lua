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
-- from won fights (Bond.settle): one for ending the fight within RANGE of the avatar, both standing, and
-- one per COVERING DEED -- a heal given to the other, a blow taken that was meant for the other, the foe
-- that last hit the other felled -- at most DEED_CAP of those a fight. The rank follows the points but
-- RISES AT MOST ONCE A RUN (`rankRun`), so a bond is built over the campaign rather than in one dive, and
-- rotating who walks down pays.
--
-- WHAT A RANK GIVES:
--   every rank  a bonded ally within RANGE of the avatar gains Hit and Avoid (Bond.HIT) -- accuracy only,
--               because the avatar is Balance.REFERENCE and a damage bonus would move every enemy band;
--   B           Trade Places and Teamwork, the avatar's two once-a-fight verbs (models/combat.lua);
--   A           Follow-up (an adjacent A partner adds a blow when the avatar strikes, once a round) and
--               Stand Firm (either partner falls, the other surges).
--
-- Rowan and Xin start at B -- the ties are older than the trade. Everyone else, the other five
-- companions included, starts at nothing. A hire's bond goes when the hire does (Bond.forget).
--
-- No love.graphics here: this loads under the headless runner (tests/bond_spec.lua).

local Bond = {}

Bond.AVATAR_ID = "character_avatar"

-- The ranks, lowest first. A pair below C has points and no rank.
Bond.RANKS = { "C", "B", "A" }
Bond.THRESHOLD = { C = 3, B = 8, A = 16 }

-- The accuracy a rank lends, on Hit when the partner swings and on Avoid when it is swung at.
Bond.HIT = { C = 5, B = 10, A = 15 }

-- How close to the avatar a partner has to stand for the bonus, and to end a fight to earn its point.
Bond.RANGE = 2

-- Covering deeds counted per fight, per pair, on top of the fight's own point.
Bond.DEED_CAP = 2

-- Who starts bonded, and at what rank. Childhood friends; nobody else.
Bond.START = { character_rowan = "B", character_xin = "B" }

local INDEX = { C = 1, B = 2, A = 3 }

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

-- The rank after `rank`, or nil at A.
function Bond.nextRank(rank) return Bond.RANKS[Bond.rankIndex(rank) + 1] end

-- Points still owed to the next rank, or nil at A.
function Bond.toNext(player, charId)
    local nxt = Bond.nextRank(Bond.rank(player, charId))
    if not nxt then return nil end
    return math.max(0, Bond.THRESHOLD[nxt] - Bond.points(player, charId))
end

-- Add `n` points to the pair and let the rank rise -- once, and only if it has not already risen in run
-- `run`. Returns `from, to` when it rose (from may be nil: a first rank), nothing otherwise.
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
    if nxt and e.points >= Bond.THRESHOLD[nxt] and e.rankRun ~= run then
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
-- the Armory's BONDS list walks. Only bodies on the roster; a pair with no points is left out.
function Bond.list(player)
    local out = {}
    for _, char in ipairs((player and player.roster) or {}) do
        if not Bond.isAvatar(char) then
            local e = Bond.entry(player, char.id)
            if e and (e.points or 0) > 0 then
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

-- The fight-only traits a body carries for its bond (Trait.attach): an A-rank partner follows up and
-- stands firm; the avatar stands firm when it holds any A-rank bond in this fight's snapshot.
function Bond.traitsFor(combat, unit)
    local ranks = combat and combat.bonds
    local char = unit and unit.char
    if not (ranks and char and char.id) or unit.side ~= "party" or unit.summoned then return {} end
    if Bond.isAvatar(char) then
        for _, rank in pairs(ranks) do
            if rank == "A" then return { "trait_bond_stand_firm" } end
        end
        return {}
    end
    if ranks[char.id] == "A" then return { "trait_bond_follow_up", "trait_bond_stand_firm" } end
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
-- A), the other five companions three times. Nil for a hire -- hires never speak -- and for a pair with no
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

-- SETTLE A WON FIGHT. `units` is the board's unit list; `deeds` is { [charId] = n } of covering deeds the
-- fight counted (Combat's bond ledger), capped here at DEED_CAP. A partner earns the fight's point only if
-- it and the avatar both ended the fight standing within RANGE; deeds count whether or not it did.
-- Returns the rises as { { id, char, from, to } } in roster order, for the bond card.
function Bond.settle(player, units, deeds, run)
    if not player then return {} end
    run = run or Bond.runOf(player)
    local avatar
    for _, u in ipairs(units or {}) do
        if u.char and Bond.isAvatar(u.char) and u.side == "party" then avatar = u end
    end
    local earned = {}
    for _, u in ipairs(units or {}) do
        local char = u.char
        if char and char.id and not Bond.isAvatar(char) and u.side == "party" and not u.summoned then
            local n = 0
            if avatar and avatar.alive and u.alive and Bond.gap(avatar, u) <= Bond.RANGE then n = 1 end
            n = n + math.min(Bond.DEED_CAP, (deeds and deeds[char.id]) or 0)
            if n > 0 then earned[char.id] = (earned[char.id] or 0) + n end
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
