-- WOUNDS: what a body carries while it is still underground.
--
-- The descent needed a meter that degrades the company as an expedition runs long, and it had none.
-- Every fight refilled at the next camp, so the sixth fight of a dive cost no more than the first and
-- "push on or take the stair" had one answer.
--
-- A WOUND RESERVES PART OF THE BODY, AND STACKS DEBUFFS AS THEY ACCUMULATE. Two halves:
--
--   the reserve   a share of the body's health pool is set aside and cannot be healed into, in the
--                 fight as well as out of it (Wound.reserveShare -> `char.woundShare`, read by
--                 Combat.unreservedMax alongside every other reservation). A wounded body does not
--                 merely start a fight short -- it cannot be topped back up past the wound by anything
--                 the floors have, which is what makes the injury a condition rather than a bad opening.
--   the debuffs   at two wounds the body fights Wounded (data/status/status_wounded.lua, a damage
--                 penalty that scales with the count); at three it is Crippled as well. Stamped at
--                 spawn through the same seam a relic's opening boon uses, so nothing in combat had to
--                 learn what a wound is.
--
-- IT LASTS AN EXPEDITION, AND THE TOWN IS WHERE IT ENDS (Wound.clear). That scope is the whole design
-- and it was arrived at the hard way, so it is worth writing down what it replaced.
--
-- A wound used to be PERMANENT until it was paid off -- first at a surgeon's counter for gold, then at
-- an Inn, where a body took a bed for a day a wound and was out of the company while it lay in one.
-- Both were the same defect wearing different clothes, and it is stated in docs/the-count.md as a law
-- this file was breaking:
--
--     A cost on recovery is a tax on NEEDING to recover, and needing to recover is what being bad at
--     the game looks like.
--
-- The Inn charged coin at the door and days in the bed, and a wipe wounds the whole expedition by
-- construction -- everybody fell, that is what a wipe is. So a company that lost badly woke poorer,
-- worse, and holding a bill; and with a roster of two to four bodies (the seven companions arrive at
-- their houses' openers, one circle at a time) there was nobody to rotate in and no way to earn the
-- coin except to go back down hurt. That is a spiral, and it is entered by losing.
--
-- WHAT PACES THE CAMPAIGN INSTEAD IS THE COUNT (models/descent.lua's Descent.count), which did not
-- exist when this file was written. It rides on the player rather than the run, it climbs on the one
-- event in the loop that is a decision with an alternative -- coming back up early -- and it can never
-- lock anybody out, because every floor descended pays a mark off. There is no longer any need for a
-- second cross-run attrition meter, and this one was the worse of the two: four ledgers instead of one
-- number, and the only one of them that could make a company unable to continue.
--
-- SO THE TWO CLOCKS HAVE TWO SCOPES. The wound paces one dive -- it is what makes the fourth fight
-- since the last camp a real question -- and the count paces the campaign. Neither compounds into the
-- other, and going home is once again the thing that makes you whole.
--
-- UNDERGROUND THERE IS STILL A WAY BACK, and it has to be a decision rather than a service. A Rest
-- stop's fourth option binds bones instead of healing, sharpening or studying (states/game.lua's
-- restBind), and a handful of crossroads dilemmas offer the same through `ctx.mendWound`. Both are
-- taken INSTEAD of something, which is the property the Inn never had.
--
-- The alternative to a reservation was a penalty on max health, and it was rejected twice over: max
-- health is derived (level, growth, gear), so a wound written into it has to be un-written exactly on
-- the way out and fights every recomputation in between; and a body whose CEILING drops reads as
-- permanently diminished rather than as hurt. A reservation says the right thing instead -- the pool is
-- the size it always was, and part of it is not available to you -- and it rides machinery that already
-- exists.
--
-- WHY IT IS STILL KEYED TO THE PERMANENT CORE. Wounds are keyed by character id on the PLAYER, not on
-- the roster instance, and that survives the scope change for the reasons that always applied: the id
-- survives the roster being rebuilt from a save mid-expedition, and the heroes bound to a single
-- descent are on the run rather than the roster, so they cannot accumulate a history the way the avatar
-- and the seven companions do. Nothing here needs to know about that distinction -- it falls out of who
-- has an id worth remembering.

local Wound = {}

-- What one wound reserves, as a share of the body's health pool. Three wounds leave a body at 55% of
-- itself and the fourth changes nothing (see FLOOR), which is deliberate: the meter is meant to make
-- the player weigh going deeper, never to make the company unplayable. A body that cannot fight is a
-- body the player benches, and a descent has no bench -- so a wound that made somebody unfieldable
-- would take a quarter of the company off the board as surely as killing them.
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
-- out of ON THIS DIVE.
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
-- measured in ticks, so it does not tick down -- what ends it is a bound bone or the walk home.
Wound.LASTING = 9999

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
-- Called from every seam that can move a wound or rebuild a body: inflict, mend, clear and
-- Player.restore. Cheap enough (a walk of four bodies) to call freely rather than to reason about.
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
    -- ...and the mark that arms the one-time coach. See Wound.everWounded.
    if #hurt > 0 then player.wounded = true end
    return hurt
end

-- HAS THIS COMPANY EVER BEEN HURT? A one-way mark, written the first time anybody takes a wound and
-- never cleared -- not by binding the last bone, not by walking home.
--
-- WHAT READS IT IS THE COACH (states/game.lua's inflictWounds): the dark cap a wound draws across a
-- body's bar in the party strip is a thing the player has never seen before and will be routing around
-- for the rest of the dive, so the very first one gets a bubble naming it. Once, ever.
--
-- IT USED TO OPEN A DOOR as well -- the Inn grew on the plaza the night the first body was carried up
-- broken -- and that building is gone with the ledger it charged for (see the header). The mark stays
-- because the lesson does.
--
-- A FIELD OF ITS OWN rather than an entry in `player.flags`, and the reason is New Game+. Flags are the
-- general-purpose "something happened once" ledger and they RESET there, along with the quest ledger and
-- the temptation record, because those are the campaign starting over. This is not a thing the campaign
-- did, it is a thing that happened to these bodies. It sits beside `player.deepest` instead: two facts
-- about the company that outlive everything.
function Wound.everWounded(player)
    return (player and player.wounded) == true
end

-- TAKE `n` WOUNDS OFF EVERY BODY THAT IS CARRYING ONE. What the floors' own bone-setting runs through:
-- a Rest stop's fourth option and the crossroads dilemmas that offer it (`ctx.mendWound`).
--
-- THE WHOLE COMPANY RATHER THAN A CHOSEN BODY, and that is a decision rather than a shortcut. Picking
-- a head would open a second modal on top of a modal, and it would turn a stop that is meant to be a
-- weigh -- bind, or heal, or sharpen, or study -- into a small optimisation puzzle about which of four
-- bars to nudge. The expedition is four bodies and they are all carrying the same dive.
--
-- Returns the ids it actually moved, sorted, so a caller can name them. Nobody hurt returns an empty
-- list, which is why the controls that call this draw only when somebody is.
function Wound.mend(player, n)
    if not (player and player.wounds) then return {} end
    n = n or 1
    local mended = {}
    for _, char in ipairs(player.roster or {}) do
        local have = player.wounds[char.id]
        if have and have > 0 then
            local left = have - n
            -- Cleared to nil rather than left at zero: models/save.lua drops empty entries, and a table
            -- of zeroes would grow forever with every body that has ever been hurt once.
            player.wounds[char.id] = left > 0 and left or nil
            mended[#mended + 1] = char.id
        end
    end
    Wound.stamp(player)
    table.sort(mended)
    return mended
end

-- THE TOWN SETS EVERY BONE, FREE. Called on arrival at the city and at the Gate (states/hub.lua,
-- states/gate.lua) -- the two screens that are above ground -- so an expedition's damage ends with the
-- expedition however it ended: by the stair, by walking out, or by being carried out.
--
-- FREE AND UNCONDITIONAL, which is the point rather than an oversight. See the header: a price on this
-- lands only on the player who needed it, and the campaign's pacing is the count's job now.
--
-- Returns the ids it mended, so a caller can say so -- though both callers are a screen the player
-- walked into rather than a button they pressed, and neither needs to.
function Wound.clear(player)
    if not (player and player.wounds) then return {} end
    local mended = {}
    for id in pairs(player.wounds) do mended[#mended + 1] = id end
    player.wounds = {}
    Wound.stamp(player)
    table.sort(mended)
    return mended
end

-- Everyone on the roster carrying at least one, as { { char, count }, ... } in roster order. What the
-- party sheet walks, and what the controls that bind bones ask before they draw.
function Wound.wounded(player)
    local out = {}
    for _, char in ipairs((player and player.roster) or {}) do
        local n = Wound.count(player, char.id)
        if n > 0 then out[#out + 1] = { char = char, count = n } end
    end
    return out
end

return Wound
