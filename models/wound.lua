-- WOUNDS: what a body carries out of a fight it lost.
--
-- The descent needed a meter that degrades the company, and it had none. Measured against the
-- references, that was the missing third of the loop: Hades gets away without one because a run is
-- twenty-five minutes, and Darkest Dungeon has four (light, stress, food, afflictions). Here the hub
-- free-healed everyone on entry and a downed member simply stood back up at a fifth of their health,
-- so nothing a run did to the company outlived the run. A wipe cost the haul and nothing else.
--
-- A WOUND IS A CAP ON THE FREE HEAL, and that is the whole mechanic.
--
-- The alternative was a penalty on max health, and it was rejected twice over: max health is derived
-- (level, growth, gear), so a wound written into it has to be un-written exactly on the way out and
-- fights every recomputation in between; and a body whose ceiling drops reads as permanently
-- diminished rather than as hurt. A cap on the REFILL says the right thing instead -- the company is
-- whole, this one is not yet -- and it needs exactly one seam, Player.restore, which is already the
-- one place "everybody is fine again" is decided.
--
-- So: the hub still heals for free, and a wounded body is topped up to less than full. It walks into
-- the next descent short, every fight of it, until somebody pays to set the bone.
--
-- WHY IT BITES THE PERMANENT CORE. Wounds are keyed by character id on the PLAYER, not on the roster
-- instance, for three reasons that all point the same way: the id survives the roster being rebuilt
-- from a save, a wipe's rollback restores the whole player and would otherwise hand the wounds back
-- with the loot (states/game.lua's rollbackRun preserves this one key explicitly), and the heroes
-- bound to a single descent are on the run rather than the roster, so they cannot accumulate a
-- history the way the avatar and the seven companions do. Nothing here needs to know about that
-- distinction -- it falls out of who has an id worth remembering.

local Wound = {}

-- What one wound takes off the hub's refill. Three wounds leave a body at 55% and the fourth changes
-- nothing (see FLOOR), which is deliberate: the meter is meant to make the player weigh a descent,
-- never to make the company unplayable. A body that cannot fight is a body the player benches, and a
-- benched body stops being a decision.
Wound.PER_WOUND = 0.15

-- The most a body can be reduced to, however many times it has fallen. Below about half, a member is
-- not a risk to field -- they are simply not fieldable -- and the wound stops being a cost the player
-- is choosing to carry and becomes one they are working around.
Wound.FLOOR = 0.55

-- What it costs to set one, in gold. Deliberately dear enough to compete with the shelf: the whole
-- point of the meter is that a run's takings have somewhere else they are needed, so mending has to
-- be a real alternative to a purchase rather than a rounding error on the way past.
Wound.MEND_COST = 120

-- How many wounds `charId` carries.
function Wound.count(player, charId)
    if not (player and charId) then return 0 end
    return (player.wounds or {})[charId] or 0
end

-- The share of full health the hub's free heal will give this body back: 1.0 whole, less for each
-- wound, never under the floor.
function Wound.healShare(player, charId)
    local n = Wound.count(player, charId)
    if n <= 0 then return 1 end
    return math.max(Wound.FLOOR, 1 - Wound.PER_WOUND * n)
end

-- Mark `chars` as having fallen. Takes the character INSTANCES the battle carried out (they are what
-- the combat model has to hand) and records against their ids.
--
-- One wound per fight per body, not one per fall: a member who goes down, is stood back up by a
-- companion and goes down again has had one bad fight. Deduped by id here rather than trusted to the
-- caller, because the caller is a battle that may hand the same body over twice.
--
-- Returns the ids that took a NEW wound, so the caller can name them on screen. A run that wounded
-- nobody returns an empty list rather than nil -- there is no "did anything happen" question here,
-- only "who".
function Wound.inflict(player, chars)
    if not player then return {} end
    player.wounds = player.wounds or {}
    local hurt, seen = {}, {}
    for _, char in ipairs(chars or {}) do
        local id = char and char.id
        -- A summon, a decoy or an AI escortee has no business accruing a history; only a body with an
        -- id the save will still know tomorrow can carry one.
        if id and not seen[id] then
            seen[id] = true
            player.wounds[id] = (player.wounds[id] or 0) + 1
            hurt[#hurt + 1] = id
        end
    end
    return hurt
end

-- Set one wound, for gold. Returns true when it was paid and mended, or nil plus a reason:
--   "unhurt" | "gold"
function Wound.mend(player, charId)
    if Wound.count(player, charId) <= 0 then return nil, "unhurt" end
    local Player = require("models.player")
    if (player.gold or 0) < Wound.MEND_COST then return nil, "gold" end
    Player.spendGold(player, Wound.MEND_COST)
    local left = player.wounds[charId] - 1
    -- Cleared to nil rather than left at zero: models/save.lua drops empty entries, and a table full
    -- of zeroes would grow forever with every body that has ever been hurt once.
    player.wounds[charId] = left > 0 and left or nil
    -- Give the mended share back at once rather than at the next hub entry. Paying for a repair and
    -- watching nothing change is the shape of a bug even when it is not one.
    Player.restore(player)
    return true
end

-- Everyone on the roster carrying at least one, as { { char, count }, ... } in roster order. What the
-- party sheet and the Cafe's mend list both walk.
function Wound.wounded(player)
    local out = {}
    for _, char in ipairs((player and player.roster) or {}) do
        local n = Wound.count(player, char.id)
        if n > 0 then out[#out + 1] = { char = char, count = n } end
    end
    return out
end

return Wound
