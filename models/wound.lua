-- WOUNDS: what a body carries out of a fight it lost.
--
-- The descent needed a meter that degrades the company, and it had none. Measured against the
-- references, that was the missing third of the loop: Hades gets away without one because a run is
-- twenty-five minutes, and Darkest Dungeon has four (light, stress, food, afflictions). Here the hub
-- free-healed everyone on entry and a downed member simply stood back up at a fifth of their health,
-- so nothing a run did to the company outlived the run. A wipe cost the haul and nothing else.
--
-- A WOUND RESERVES PART OF THE BODY, AND STACKS DEBUFFS AS THEY ACCUMULATE. Two halves:
--
--   the reserve   a share of the body's health pool is set aside and cannot be healed into, in the
--                 fight as well as out of it (Wound.reserveShare -> `char.woundShare`, read by
--                 Combat.unreservedMax alongside every other reservation). A wounded body does not
--                 merely start a fight short -- it cannot be topped back up past the wound by anything,
--                 which is what makes the injury a condition rather than a bad opening.
--   the debuffs   at two wounds the body fights Wounded (data/status/status_wounded.lua, a damage
--                 penalty that scales with the count); at three it is Crippled as well. Stamped at
--                 spawn through the same seam a relic's opening boon uses, so nothing in combat had to
--                 learn what a wound is.
--
-- IT IS THE STAKE THE MODE RUNS ON, and it took that job over from something harsher. A descent briefly
-- lost a body outright when its downed count ran out -- gone from the roster in a fight the company
-- WON -- and that made the countdown the whole game. Wounds do the same work along a curve instead: a
-- body that keeps going down keeps getting harder to field, until fielding it is the mistake. The only
-- thing that ever costs a body now is a WIPE, and even then they lie where they fell to be fetched.
--
-- The alternative was a penalty on max health, and it was rejected twice over: max health is derived
-- (level, growth, gear), so a wound written into it has to be un-written exactly on the way out and
-- fights every recomputation in between; and a body whose CEILING drops reads as permanently
-- diminished rather than as hurt. A reservation says the right thing instead -- the pool is the size it
-- always was, and part of it is not available to you -- and it rides machinery that already exists.
--
-- WHY IT BITES THE PERMANENT CORE. Wounds are keyed by character id on the PLAYER, not on the roster
-- instance, for three reasons that all point the same way: the id survives the roster being rebuilt
-- from a save, a wipe's rollback restores the whole player and would otherwise hand the wounds back
-- with the loot (states/game.lua's rollbackRun preserves this one key explicitly), and the heroes
-- bound to a single descent are on the run rather than the roster, so they cannot accumulate a
-- history the way the avatar and the seven companions do. Nothing here needs to know about that
-- distinction -- it falls out of who has an id worth remembering.

local Wound = {}

-- What one wound reserves, as a share of the body's health pool. Three wounds leave a body at 55% of
-- itself and the fourth changes nothing (see FLOOR), which is deliberate: the meter is meant to make
-- the player weigh a descent, never to make the company unplayable. A body that cannot fight is a body
-- the player benches, and a descent has no bench -- so a wound that made somebody unfieldable would
-- take a quarter of the company off the board as surely as killing them.
Wound.PER_WOUND = 0.15

-- The most a body can be reduced to, however many times it has fallen. Below about half, a member is
-- not a risk to field -- they are simply not fieldable -- and the wound stops being a cost the player
-- is choosing to carry and becomes one they are working around.
Wound.FLOOR = 0.55

-- THE DEBUFF LADDER, and where each rung starts.
--
-- One wound is the reserve and nothing else: the first time somebody goes down should cost them, and
-- should not start a spiral. From the SECOND the body also fights Wounded, and from the third it is
-- Crippled on top -- so the shape is a cost that grows teeth rather than a switch, and a player reading
-- two badges on one member knows without being told that this is the third fight they have been carried
-- out of.
--
-- Cripple is the catalogue's existing movement cut (data/status/status_cripple.lua) rather than a
-- second authored wound status, because it is exactly the same thing happening for a different reason
-- and the player has already learned what the badge means.
Wound.DEBUFF_AT = 2
Wound.CRIPPLE_AT = 3

-- How hard Wounded bites per wound past the first. Two points of damage a rung: enough to be read in
-- the breakdown, small enough that a wounded veteran still out-hits a fresh recruit -- which is the
-- line the whole meter walks.
Wound.DAMAGE_PER_WOUND = 2

-- Long past any battle's length. A wound is a condition the body ARRIVED with, not a tempo cost
-- measured in ticks, so it does not tick down -- what ends it is the inn.
Wound.LASTING = 9999

-- What it costs to set one, in gold. Deliberately dear enough to compete with the shelf: the whole
-- point of the meter is that a run's takings have somewhere else they are needed, so mending has to
-- be a real alternative to a purchase rather than a rounding error on the way past.
Wound.MEND_COST = 120

-- How many wounds `charId` carries.
function Wound.count(player, charId)
    if not (player and charId) then return 0 end
    return (player.wounds or {})[charId] or 0
end

-- The share of the health pool this body can still USE: 1.0 whole, less for each wound, never under the
-- floor. The rest is reserved and cannot be healed into by anything.
--
-- Still called healShare because that is what it was when the reserve did not exist and the cap only
-- applied to the hub's refill -- and because that is still exactly what it means to Player.restore.
-- Wound.reserveShare is the same number said the other way round, for the combat side.
function Wound.healShare(player, charId)
    local n = Wound.count(player, charId)
    if n <= 0 then return 1 end
    return math.max(Wound.FLOOR, 1 - Wound.PER_WOUND * n)
end

-- The share of the pool a wounded body cannot reach, which is the complement of the above. What
-- Combat.unreservedMax subtracts.
function Wound.reserveShare(player, charId)
    return 1 - Wound.healShare(player, charId)
end

-- STAMP THE RESERVE ONTO THE BODIES THEMSELVES, so the combat model never has to know a player exists.
--
-- Wounds are keyed by char id on the PLAYER (see the header); Combat.unreservedMax takes a CHARACTER
-- and no player, which is right -- it is asked about summons, enemies and duel rosters that have no
-- player behind them at all. So the share is written onto `char.woundShare` by whoever does know the
-- player, exactly as `char.maxBonus` is written by the grid pass.
--
-- Called from every seam that can move a wound or rebuild a body: inflict, mend, Player.restore, and
-- the gate's inn. Cheap enough (a walk of four bodies) to call freely rather than to reason about.
function Wound.stamp(player)
    for _, char in ipairs((player and player.roster) or {}) do
        local share = Wound.reserveShare(player, char.id)
        -- Cleared to nil rather than left at zero, so an unwounded body carries no field at all and
        -- Combat.unreservedMax's fast path is a single nil test.
        char.woundShare = share > 0 and share or nil
    end
end

-- WHAT A WOUNDED BODY FIGHTS UNDER, as a list of { id, opts } for the battle to stamp at spawn.
--
-- Returned as data rather than applied here because this module has no combat and no unit -- the caller
-- is states/game.lua's resolveOpening, which is already the one place opening statuses are resolved
-- (that is where a relic's boons come from). One seam, two sources.
--
-- Empty below Wound.DEBUFF_AT: the first wound is the reserve and nothing else.
function Wound.combatEffects(player, charId)
    local n = Wound.count(player, charId)
    local out = {}
    if n >= Wound.DEBUFF_AT then
        out[#out + 1] = { id = "status_wounded", opts = {
            -- NEGATED, and counted from the first rung that bites: at two wounds this is -2, at three
            -- -4. `magnitudeStat` is damage, so Status.statBonus subtracts it in the breakdown under
            -- its own name rather than as an unexplained shortfall.
            magnitude = -((n - Wound.DEBUFF_AT + 1) * Wound.DAMAGE_PER_WOUND),
            duration = Wound.LASTING,
        } }
    end
    if n >= Wound.CRIPPLE_AT then
        out[#out + 1] = { id = "status_cripple", opts = { duration = Wound.LASTING } }
    end
    return out
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
    -- The reserve moves the instant the ledger does. Without this a body wounded at the end of a fight
    -- would walk to the next stop still able to heal into ground it has just lost.
    Wound.stamp(player)
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
