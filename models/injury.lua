-- INJURIES: what a body carries after it has been carried off a floor, and what each one costs.
--
-- The descent needed a meter that degrades the company as an expedition runs long, and it had none.
-- Every fight refilled at the next camp, so the sixth fight of a dive cost no more than the first and
-- "push on or take the stair" had one answer.
--
-- AN INJURY IS A NAMED THING, NOT A TALLY -- which is the change of 2026-09-22 and the reason this file
-- reads differently from the one a long comment history describes. It used to be a COUNT: every body
-- that fell took the same 15% off its health pool, a damage debuff arrived at two, a movement cut at
-- three, and the only thing that varied was how many. One kind of harm, three rungs deep.
--
-- Now a fall deals one of SEVEN, rolled (data/injuries/), each with its own name, its own reserve and
-- its own badge:
--
--   Blood Loss        the pool, and nothing else -- 15%, no badge. The old meter, kept whole.
--   Shattered Leg     movement -2
--   Torn Shoulder     damage -3
--   Cracked Ribs      defense -3
--   Rattled           skill -3, speed -1
--   Burst Lung        staminaRegen -1, and a fifth of the stamina pool
--   Ruptured Font     magicDamage -3, and a quarter of the mana pool
--
-- WHY A BLUEPRINT FOLDER rather than a table in here: it is the shape every other content type in this
-- tree already has (models/registry.lua auto-loads `data/<type>/`), so an eighth injury is a file and
-- nothing else, and the wiki, the specs and the tooling that walk content folders get it for free.
--
-- THE TWO HALVES ARE UNCHANGED, and that is the point -- nothing downstream learned a new mechanism:
--
--   the reserve   a share of a POOL is set aside and cannot be healed into, in the fight as well as out
--                 of it. It was health-only and a single number; it is now a table per stat
--                 (`char.injuryShare = { health = .., mana = .. }`, read by Combat.unreservedMax) so a
--                 Ruptured Font can seal mana the same way Blood Loss seals health. Everything else
--                 about it holds: `max` is never written, so nothing has to be un-written on the way
--                 out and every recomputation from level and gear stays untouched.
--   the badges    each kind stamps its OWN status at spawn, through the same seam a relic's opening
--                 boon uses (states/game.lua's resolveOpening). They stack; what stops them running
--                 away is Injury.STAT_FLOOR.
--
-- THE BADGES ARE UNCLEANSABLE, AND THAT FIXED A LIVE BUG. The count-based meter stamped
-- `status_cripple` at three wounds -- and Cripple is `debuff = true`, which means Status.cleanse strips
-- it. One Cure lifted the campaign's attrition meter for the rest of the fight, and nothing in the item
-- or the meter knew. Every injury status is authored `debuff = false`, so the only thing that ends one
-- is the Ward.
--
-- IT LASTS UNTIL SOMEBODY SETS IT, AND THE WARD IS THE ONLY ROOM THAT DOES.
--
-- THIS HEADER SAID THE OPPOSITE FOR A WHILE and the file argued against the system it implements, which
-- is worth flagging rather than quietly correcting: it read "IT LASTS AN EXPEDITION, AND THE TOWN IS
-- WHERE IT ENDS (Injury.clear)", and Injury.clear has not stood in states/hub.lua's enter or in
-- states/gate.lua for some time -- both sites survive only as comments saying it was taken out. An
-- injury now outlives the trip that dealt it. Everything downstream reads this file to learn what an
-- injury is, so a stale sentence here is one that gets believed.
--
-- WHERE IT ACTUALLY ENDS is the Cathedral's mending (data/buildings/cathedral.lua), and in exactly two
-- ways: REST, free and always open, which lays the body up for Injury.REST_DESCENTS trips and is paid in
-- who walks down without them; or TREAT, Injury.TREAT_COST in gold, which sets the bone before you leave
-- the room. Gold buys SPEED and never recovery -- the distinction docs/the-count.md's law turns on, and
-- the reason the price does NOT move with the kind: charging more for a Shattered Leg than for Blood
-- Loss would tax the worse luck, and the worse luck already cost you the injury.
--
-- WHICH MAKES IT DARKEST DUNGEON'S METER rather than a within-dive one: the cost of a bad trip is a
-- body on the bench and a company that goes down thinner, never a bill. That is the shape the game is
-- built to now.
--
-- The scope below was arrived at the hard way, so it is worth writing down what it replaced.
--
-- An injury used to be PERMANENT until it was paid off -- first at a surgeon's counter for gold, then at
-- an Inn, where a body took a bed for a day an injury and was out of the company while it lay in one.
-- Both were the same defect wearing different clothes, and it is stated in docs/the-count.md as a law
-- this file was breaking:
--
--     A cost on recovery is a tax on NEEDING to recover, and needing to recover is what being bad at
--     the game looks like.
--
-- The Inn charged coin at the door and days in the bed, and a wipe injures the whole expedition by
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
-- SO THE TWO CLOCKS HAVE TWO SCOPES. The injury paces one dive -- it is what makes the fourth fight
-- since the last camp a real question -- and the count paces the campaign. Neither compounds into the
-- other, and going home is once again the thing that makes you whole.
--
-- UNDERGROUND THERE IS STILL A WAY BACK, and it has to be a decision rather than a service. A Rest
-- stop's fourth option binds bones instead of healing, sharpening or studying (states/game.lua's
-- restBind), and a handful of crossroads dilemmas offer the same through `ctx.mendWound`. Both are
-- taken INSTEAD of something, which is the property the Inn never had.
--
-- The alternative to a reservation was a penalty on max health, and it was rejected twice over: max
-- health is derived (level, growth, gear), so an injury written into it has to be un-written exactly on
-- the way out and fights every recomputation in between; and a body whose CEILING drops reads as
-- permanently diminished rather than as hurt. A reservation says the right thing instead -- the pool is
-- the size it always was, and part of it is not available to you -- and it rides machinery that already
-- exists.
--
-- WHY IT IS STILL KEYED TO THE PERMANENT CORE. Injuries are keyed by character id on the PLAYER, not on
-- the roster instance, and that survives the scope change for the reasons that always applied: the id
-- survives the roster being rebuilt from a save mid-expedition, and the heroes bound to a single
-- descent are on the run rather than the roster, so they cannot accumulate a history the way the avatar
-- and the seven companions do. Nothing here needs to know about that distinction -- it falls out of who
-- has an id worth remembering.

local Registry = require("models.registry")
local Seed = require("models.seed")

local Injury = {}

-- THE CATALOGUE. One file per kind under data/injuries/, keyed by filename exactly as items, statuses
-- and characters are. A blueprint declares:
--
--   name, description   what the body card and the Ward print
--   severity            how deep it is. A camp's field dressing sets the SHALLOWEST (Injury.mend), and
--                       so does the Ward's single press -- there is no picker anywhere, by decision, so
--                       this number is the whole answer to "which bone came off".
--   weight              its share of the roll. The seven ship summing to 100, so each reads as its own
--                       percentage; nothing enforces that and the draw normalises over whatever is
--                       there.
--   reserve             { stat = share } -- what it locks out of each pool. Summed across a body's
--                       injuries and floored at Injury.FLOOR per stat.
--   effects             { { id = "status_..." }, ... } -- what it fights under, stamped at the bell.
Injury.defs = Registry.load("data/injuries", "data.injuries")

-- The catalogue in a stable order. `pairs` over a registry is hash order, which moves when an unrelated
-- module interns its strings earlier in the run -- and a WEIGHTED DRAW walked in hash order would deal
-- a different injury on a tree where somebody added a require. Sorted once, cached, and every walk that
-- can be seen by the player goes through it.
local ORDER
function Injury.order()
    if not ORDER then
        ORDER = {}
        for id in pairs(Injury.defs) do ORDER[#ORDER + 1] = id end
        table.sort(ORDER)
    end
    return ORDER
end

-- The most of a POOL that injuries can take, however many a body carries. Below about half, a member is
-- not a risk to field -- they are simply not fieldable -- and the injury stops being a cost the player
-- is choosing to carry and becomes one they are working around.
--
-- "A DESCENT HAS NO BENCH" STOOD HERE and is no longer true, which changes what this number is for. It
-- was written when the company was the four who walked down; the roster is unbounded (models/player.lua)
-- and fills one house companion per descent (Descent.dealCompanion), so a company several trips in is
-- ten bodies deep against four seats -- and Descent.party already skips anybody laid up at the Ward and
-- takes the next one instead. The bench exists and is walked onto automatically.
--
-- So the floor is no longer the thing standing between an injury and an unplayable company -- the bench
-- is. It stays where it is anyway, because it governs the body you choose to field ANYWAY, which is the
-- interesting case: an injured veteran who still out-hits a fresh recruit is the decision this meter is
-- for, and that only reads if the injured body remains worth fielding.
Injury.FLOOR = 0.55

-- ...AND THE SAME LAW FOR EVERY OTHER STAT, which is new and is what makes stacking safe.
--
-- The review of 2026-09-22 settled that injuries STACK -- a body can take a second Shattered Leg, and it
-- bites again. The reserve has always had a floor; the stat cuts did not, so six bad trips would have
-- read -12 movement and a body that cannot leave its tile. A cut can never take a stat below a quarter
-- of what the body's own blueprint says it is, and never below 1 -- so the arithmetic that makes a
-- veteran worse can never make them inert, which is exactly what Injury.FLOOR promises for the pools.
--
-- Measured against the CHARACTER's base rather than its equipped total, deliberately: a body's gear
-- changes between trips and a floor that moved with it would mean taking a shield off could deepen an
-- old injury.
Injury.STAT_FLOOR = 0.25

-- Long past any battle's length. An injury is a condition the body ARRIVED with, not a tempo cost
-- measured in ticks, so it does not tick down -- what ends it is a bound bone or the Ward.
Injury.LASTING = 9999

-- WHAT `charId` IS CARRYING, oldest first, as blueprint ids. The ledger IS this list -- it used to be a
-- number, and the migration in models/save.lua turns an old save's count into that many Blood Loss
-- (which is what the number meant), rather than re-rolling a company in the load screen.
--
-- Always a fresh table for a body with nothing, so a caller can walk the result without a nil test and
-- cannot accidentally write a row into the ledger by touching it.
function Injury.list(player, charId)
    if not (player and charId) then return {} end
    return (player.injuries or {})[charId] or {}
end

-- How many `charId` carries.
function Injury.count(player, charId)
    return #Injury.list(player, charId)
end

-- The body's injuries as { id, def } in SHALLOWEST-FIRST order: severity, then name, then the order they
-- were taken. What a field dressing spends itself on and what the Ward's press takes off.
--
-- A total order rather than "the first one with the lowest severity", because two bodies carrying the
-- same three injuries must have the same bone set -- otherwise the one rule the player is given ("a camp
-- sets what a camp can set") is true only on average.
function Injury.sorted(player, charId)
    local out = {}
    for i, id in ipairs(Injury.list(player, charId)) do
        out[#out + 1] = { id = id, def = Injury.defs[id] or {}, at = i }
    end
    table.sort(out, function(a, b)
        local sa, sb = a.def.severity or 0, b.def.severity or 0
        if sa ~= sb then return sa < sb end
        local na, nb = a.def.name or a.id, b.def.name or b.id
        if na ~= nb then return na < nb end
        return a.at < b.at
    end)
    return out
end

-- WHAT THIS BODY CANNOT REACH, per pool, as { stat = share }. Each stat's shares are summed across every
-- injury the body carries and capped at 1 - Injury.FLOOR, so no pool is ever more than 45% sealed.
--
-- Returns nil when there is nothing to say, so every caller's fast path is a single nil test.
function Injury.reserve(player, charId)
    local out, any = {}, false
    for _, id in ipairs(Injury.list(player, charId)) do
        local def = Injury.defs[id]
        for stat, share in pairs((def and def.reserve) or {}) do
            out[stat] = (out[stat] or 0) + share
            any = true
        end
    end
    if not any then return nil end
    local cap = 1 - Injury.FLOOR
    for stat, share in pairs(out) do
        out[stat] = math.min(cap, share)
    end
    return out
end

-- The share of the HEALTH pool this body can still use: 1.0 whole, less for each injury that takes
-- health, never under the floor. The rest is reserved and cannot be healed into by anything.
--
-- Still called healShare because that is what it was when the reserve did not exist and the cap only
-- applied to the hub's refill -- and because that is still exactly what it means to Player.restore.
-- Health alone, because that is the pool the hub and the camp refill; the other pools answer through
-- Combat.unreservedMax, which reads the whole table.
function Injury.healShare(player, charId)
    local reserve = Injury.reserve(player, charId)
    return 1 - ((reserve and reserve.health) or 0)
end

-- The health share an injured body cannot reach, which is the complement of the above.
function Injury.reserveShare(player, charId)
    return 1 - Injury.healShare(player, charId)
end

-- STAMP THE RESERVE ONTO THE BODIES THEMSELVES, so the combat model never has to know a player exists.
--
-- Injuries are keyed by char id on the PLAYER (see the header); Combat.unreservedMax takes a CHARACTER
-- and no player, which is right -- it is asked about summons, enemies and duel rosters that have no
-- player behind them at all. So the share is written onto `char.injuryShare` by whoever does know the
-- player, exactly as `char.maxBonus` is written by the grid pass.
--
-- Called from every seam that can move an injury or rebuild a body: inflict, mend, treat, tickRest and
-- Player.restore. Cheap enough (a walk of four bodies) to call freely rather than to reason about.
function Injury.stamp(player)
    for _, char in ipairs((player and player.roster) or {}) do
        -- Cleared to nil rather than left as an empty table, so an unhurt body carries no field at all
        -- and Combat.unreservedMax's fast path is a single nil test.
        char.injuryShare = Injury.reserve(player, char.id)
    end
end

-- The most an injury may take off `stat` on this body: never below a quarter of its own base, never
-- below 1. See Injury.STAT_FLOOR.
--
-- A body we were handed nothing about (no char, no such stat) gets no allowance rather than an infinite
-- one: a missing base is a question this cannot answer, and answering it generously is how a stat
-- reaches zero without anybody deciding it should.
local function allowance(char, stat)
    local base = char and char.stats and char.stats[stat]
    if type(base) ~= "number" then return 0 end
    local floor = math.max(1, math.floor(base * Injury.STAT_FLOOR))
    return math.max(0, base - floor)
end

-- WHAT AN INJURED BODY FIGHTS UNDER, as a list of { id, opts } for the battle to stamp at spawn.
--
-- Returned as data rather than applied here because this module has no combat and no unit -- the caller
-- is states/game.lua's resolveOpening, which is already the one place opening statuses are resolved
-- (that is where a relic's boons come from). One seam, two sources.
--
-- `char` is the body the injuries are on, and it is what the clamp is measured against. It is optional
-- only so a caller holding an id and no instance still gets the badges; without it the authored
-- magnitudes stand and nothing is floored, which is right for a bare readout and would be wrong for a
-- fight -- so the battle always passes it.
--
-- ONE BADGE PER KIND, HOWEVER MANY OF THAT KIND THE BODY CARRIES. Injuries stack (the review of
-- 2026-09-22 settled that outright), but Status.apply REFRESHES an existing status rather than adding a
-- second instance -- so two Shattered Legs handed over as two effects would silently land as one -2
-- rather than the -4 the ledger says. They are summed here instead and handed over once, which is also
-- the honest readout: the player wants to know what their leg is worth now, not that it was broken
-- twice.
--
-- THE CLAMP IS SPENT SHALLOWEST-FIRST, and the badge shows what was actually taken. An injury can never
-- take a stat below a quarter of the body's own base (Injury.STAT_FLOOR), so a body at movement 4
-- carrying two Shattered Legs reads -3 and not -4 -- a badge that promises a number the body is not
-- paying is the same defect as a damage breakdown that does not add up.
function Injury.combatEffects(player, charId, char)
    local Status = require("models.status")
    local out, byId, spent = {}, {}, {}
    for _, entry in ipairs(Injury.sorted(player, charId)) do
        for _, effect in ipairs(entry.def.effects or {}) do
            local slot = byId[effect.id]
            if not slot then
                slot = { id = effect.id, opts = { duration = Injury.LASTING } }
                byId[effect.id] = slot
                out[#out + 1] = slot
            end
            for k, v in pairs(effect.opts or {}) do slot.opts[k] = v end

            local def = Status.defs[effect.id]
            local authored = def and def.statBonus
            if authored then
                local bonus = slot.opts.statBonus or {}
                for stat, amount in pairs(authored) do
                    if amount < 0 and char then
                        local left = allowance(char, stat) - (spent[stat] or 0)
                        local take = math.max(0, math.min(-amount, left))
                        spent[stat] = (spent[stat] or 0) + take
                        bonus[stat] = (bonus[stat] or 0) - take
                    else
                        bonus[stat] = (bonus[stat] or 0) + amount
                    end
                end
                slot.opts.statBonus = bonus
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- The roll
-- ---------------------------------------------------------------------------

-- Fold a character id into a number the mixer can take. Lua 5.1 has no bit operators (see
-- models/seed.lua's note), so this is multiply-and-add under the same prime the seed mixes with.
local function fold(text)
    local n = 0
    for i = 1, #text do
        n = (n * 31 + text:byte(i)) % 2147483647
    end
    return n
end

-- WHICH INJURY THIS BODY TAKES. Dealt from the save's own seed, the depth, who fell and how many they
-- already carry -- never from `math.random`.
--
-- THE SAME RULE THE FLOORS KEEP. A floor's ground is dealt from the seed and the depth alone, so floor
-- three is the same floor three for the life of a playthrough (models/descent.lua). An injury is the
-- other thing a trip hands you and it obeys the same law: reload before the fight and the same bone
-- breaks. A live roll would make save-scumming the optimal way to play a meter whose entire job is to
-- make you live with what happened, and it would make every spec that touches an injury a coin flip.
--
-- THE COUNT IS IN THE MIX, so a body carried out twice on one floor does not take the same injury twice
-- for free -- the second draw is a different draw. Duplicates are still possible and still stack, which
-- the review settled on purpose; what this stops is the degenerate case where they are CERTAIN.
--
-- Weighted over the whole catalogue with no `fits` gate: a Ruptured Font can land on a fighter with five
-- mana, and the 6% health reserve every kind carries is what stops that being a roll that cost nothing.
function Injury.roll(player, charId, carried)
    local order = Injury.order()
    if #order == 0 then return nil end

    local total = 0
    for _, id in ipairs(order) do
        total = total + ((Injury.defs[id].weight) or 0)
    end
    -- A catalogue that weights nothing still has to answer, so fall back to an even draw rather than
    -- dividing by zero or always dealing the alphabetically first kind.
    local even = total <= 0

    local base = (player and player.seed) or 0
    local run = player and Seed.run and Seed.run(player) or base
    local depth = (player and player.descentRun and player.descentRun.floor) or 0
    local roll = Seed.mix(run, depth * 7919 + 1, fold(charId or ""), (carried or 0) + 1)
    local pick = roll % (even and #order or total)

    for _, id in ipairs(order) do
        local w = even and 1 or ((Injury.defs[id].weight) or 0)
        if pick < w then return id end
        pick = pick - w
    end
    return order[#order]
end

-- Mark `chars` as having fallen, and deal each of them an injury. Takes the character INSTANCES the
-- battle carried out (they are what the combat model has to hand) and records against their ids.
--
-- One injury per fight per body, not one per fall: a member who goes down, is stood back up by a
-- companion and goes down again has had one bad fight. Deduped by id here rather than trusted to the
-- caller, because the caller is a battle that may hand the same body over twice.
--
-- `kind` names a blueprint to deal instead of rolling, and exists for the two places the game must know
-- exactly what the player is looking at: the prologue's scripted fall (states/prologue.lua -- the coach
-- bubble points at a dark band on Rowan's bar, so she takes Blood Loss and never a Shattered Leg that
-- draws no band), and a trap or a crossroads that says what it did to you.
--
-- Returns the ids that took a NEW injury, so the caller can name them on screen. A run that injured
-- nobody returns an empty list rather than nil -- there is no "did anything happen" question here,
-- only "who".
function Injury.inflict(player, chars, kind)
    if not player then return {} end
    player.injuries = player.injuries or {}
    local hurt, seen = {}, {}
    for _, char in ipairs(chars or {}) do
        local id = char and char.id
        -- A summon, a decoy or an AI escortee has no business accruing a history; only a body with an
        -- id the save will still know tomorrow can carry one.
        if id and not seen[id] then
            seen[id] = true
            local list = player.injuries[id] or {}
            local dealt = kind or Injury.roll(player, id, #list)
            local def = dealt and Injury.defs[dealt]
            if def then
                list[#list + 1] = dealt
                player.injuries[id] = list
                hurt[#hurt + 1] = id
                -- ...and the SECOND one-way mark, for the second lesson. See Injury.everBadged.
                if def.effects and def.effects[1] then player.injuredBadge = true end
            end
        end
    end
    -- The reserve moves the instant the ledger does. Without this a body injured at the end of a fight
    -- would walk to the next stop still able to heal into ground it has just lost.
    Injury.stamp(player)
    -- ...and the mark that arms the one-time coach. See Injury.everInjured.
    if #hurt > 0 then player.injured = true end
    return hurt
end

-- HAS THIS COMPANY EVER BEEN HURT? A one-way mark, written the first time anybody takes an injury and
-- never cleared -- not by binding the last bone, not by walking home.
--
-- WHAT READS IT IS THE COACH (states/game.lua's inflictInjuries): the dark cap an injury draws across a
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
function Injury.everInjured(player)
    return (player and player.injured) == true
end

-- HAS ANYBODY EVER TAKEN ONE THAT CARRIES A BADGE? The second one-way mark, and it needs its own
-- ledger for the reason two one-time flags always do: it answers a different question from
-- Injury.everInjured and the two become true on different days.
--
-- THE LESSON IT ARMS IS THE OTHER HALF OF THE MECHANIC. The first bubble teaches the dark band on the
-- bar, which is Blood Loss -- and that is the one the prologue deals by name, so it is always the first
-- thing anybody sees. Five of the other six take almost nothing off the pool and instead stamp a badge
-- the body fights under, which draws in a different place, means a different thing, and cannot be
-- taught by a bubble pointing at a bar. So the first time one of THOSE lands, its own line fires once.
--
-- Split rather than folded into one longer bubble because the two halves are answerable in different
-- places: the band is read on the party strip the bubble is pinned to, and the badge is read on the
-- body card and at the bell. A single line covering both would be teaching half of itself against a
-- screen that cannot show it.
function Injury.everBadged(player)
    return (player and player.injuredBadge) == true
end

-- TAKE `n` INJURIES OFF EVERY BODY THAT IS CARRYING ONE, SHALLOWEST FIRST. What the floors' own
-- bone-setting runs through: a Rest stop's fourth option and the crossroads dilemmas that offer it
-- (`ctx.mendWound`).
--
-- THE WHOLE COMPANY RATHER THAN A CHOSEN BODY, and that is a decision rather than a shortcut. Picking
-- a head would open a second modal on top of a modal, and it would turn a stop that is meant to be a
-- weigh -- bind, or heal, or sharpen, or study -- into a small optimisation puzzle about which of four
-- bars to nudge. The expedition is four bodies and they are all carrying the same dive.
--
-- ...WHICH IS ALSO WHY IT DOES NOT ASK WHICH INJURY. Once a body could carry three different kinds, "one
-- comes off" needed an answer, and a picker here would reintroduce exactly the modal the paragraph above
-- refuses. The rule is stated instead, in the game's own words: a field dressing sets what a field
-- dressing can set -- the SHALLOWEST first (Injury.sorted). Rattled goes before Blood Loss.
--
-- Returns the ids it actually moved, sorted, so a caller can name them. Nobody hurt returns an empty
-- list, which is why the controls that call this draw only when somebody is.
function Injury.mend(player, n)
    if not (player and player.injuries) then return {} end
    n = n or 1
    local mended = {}
    for _, char in ipairs(player.roster or {}) do
        if Injury.count(player, char.id) > 0 then
            Injury.drop(player, char.id, n)
            mended[#mended + 1] = char.id
        end
    end
    Injury.stamp(player)
    table.sort(mended)
    return mended
end

-- Take the `n` shallowest injuries off one body and rewrite its row. The one place the ledger shrinks,
-- so the "cleared to nil rather than left empty" rule lives here and nowhere else: models/save.lua drops
-- empty entries, and a table of empty lists would grow forever with every body that has ever been hurt.
--
-- Does NOT stamp -- every caller either stamps once over a whole company (Injury.mend) or is about to
-- (Injury.treat), and a stamp per body would walk the roster once per bone.
function Injury.drop(player, charId, n)
    local order = Injury.sorted(player, charId)
    local cut = {}
    for i = 1, math.min(n or 1, #order) do cut[order[i].at] = true end
    local left = {}
    for i, id in ipairs(Injury.list(player, charId)) do
        if not cut[i] then left[#left + 1] = id end
    end
    player.injuries = player.injuries or {}
    player.injuries[charId] = (#left > 0) and left or nil
    return #order - #left
end

-- ---------------------------------------------------------------------------
-- The Ward: the two ways a bone gets set above ground
-- ---------------------------------------------------------------------------
--
-- REINTRODUCED 2026-09-16, and this is the THIRD pass at charging for recovery, so the two that failed
-- are worth stating before the one that did not.
--
--   1. A SURGEON'S COUNTER, gold per injury. Deleted.
--   2. AN INN: 60g an injury at the door, or a day an injury in a bed. Deleted 2026-09-02, and the autopsy
--      is in this file's header -- a wipe injuries the WHOLE expedition by construction, so a company
--      that lost badly woke poorer, worse, and holding a bill, with no bench to rotate and no way to
--      earn the coin except to go back down hurt. A spiral entered by losing.
--
-- WHAT IS DIFFERENT NOW, on the one axis that killed the Inn: RECOVERY IS FREE AND ALWAYS AVAILABLE.
-- The Inn charged at the door, so you paid to be treated at all. Here `Injury.rest` costs nothing ever,
-- and `Injury.treat` buys only SPEED. The need is free; the decision is priced. That is exactly the line
-- docs/the-count.md draws, and the reason this pass is legal where both earlier ones were not.
--
-- AND A BENCH FINALLY EXISTS. The Inn's other defect was that benching needs somebody to bench INTO,
-- and the roster was two to four bodies for most of the campaign. The company now leaves Act 0 with
-- three and fills its fourth on floor one (models/descent.lua's SCRIPTED_COMPANION), with the roll
-- adding more -- so resting a body is a choice about who goes rather than a body simply missing.
--
-- A DAY IS A DESCENT, and that is the load-bearing decision here. Nothing in this game advances the
-- calendar except walking into the stair (models/gate.lua's Gate.night, the only Calendar.spend caller),
-- and `Descent.dangerLevel` reads the day off the floor ladder rather than off the calendar -- so days
-- are nearly inert as a currency and "rest three days" priced against them would cost nothing at all.
-- Priced against DESCENTS it costs exactly the right thing: a body resting sits out that many trips, and
-- an expedition is four (Descent.PARTY_MAX). You go down short, or you go down with somebody worse.
--
-- IT ALSO DODGES THE TRAP THAT KILLED THE GATE'S "WAIT A DAY" ROW -- "a cure on the far side of the
-- fight you were too hurt to take". You never need the RESTING body to descend; you descend with whoever
-- is left, and the rest ticks because you went. An injured body is still fieldable either way (the
-- reserve floors at FLOOR), so resting is always a choice and never a lockout.

-- Gold to set one bone immediately. Priced against a rank-0 shelf item rather than against a dive's
-- takings: it has to read as "an afternoon of somebody's time", not as a fine.
Injury.TREAT_COST = 40

-- How many descents a body sits out to mend one injury for nothing. Two, so a single injury is a real
-- shrug and three injuries on one body is a decision the player actually makes rather than a formality.
Injury.REST_DESCENTS = 2

-- Is this body in the ward right now, and for how many more descents?
function Injury.resting(player, charId)
    if not (player and charId) then return 0 end
    return (player.resting or {})[charId] or 0
end

-- Everyone currently lying in the ward, as { { char, left }, ... } in roster order. What the deployment
-- picker greys and what the ward panel lists under its second heading.
function Injury.resters(player)
    local out = {}
    for _, char in ipairs((player and player.roster) or {}) do
        local left = Injury.resting(player, char.id)
        if left > 0 then out[#out + 1] = { char = char, left = left } end
    end
    return out
end

-- PAY, AND THE BONE IS SET NOW. Takes the gold and drops one injury. Returns true if it happened; false
-- when the body is not hurt or the purse is short, so the caller can say which rather than guess.
--
-- One injury per press, deliberately: a body carried out three times is three decisions, and a single
-- "mend everything" button would hide the one moment where paying stops being worth it.
function Injury.treat(player, charId)
    if not (player and charId) then return false end
    if Injury.count(player, charId) <= 0 then return false end
    local cost = Injury.TREAT_COST
    if (player.gold or 0) < cost then return false end
    player.gold = player.gold - cost
    -- THE SHALLOWEST, which is the same rule a camp's field dressing keeps (Injury.mend) -- and it is
    -- the rule rather than a picker because the review of 2026-09-22 denied naming injuries on this
    -- desk. The room is the ACT; the names are read on the body card and the deployment picker. One
    -- press, one bone, and which bone is answered the same way in both rooms so a player only ever
    -- learns it once.
    Injury.drop(player, charId, 1)
    Injury.stamp(player)
    return true
end

-- REST, AND IT COSTS ONLY TIME. Lays the body up for REST_DESCENTS trips per injury it carries. Free,
-- always, with no purse test and no gate -- see the header for why that is the whole legality of this.
--
-- Returns the number of descents it will be out, or 0 if there was nothing to rest off.
function Injury.rest(player, charId)
    if not (player and charId) then return 0 end
    local n = Injury.count(player, charId)
    if n <= 0 then return 0 end
    player.resting = player.resting or {}
    local owed = n * Injury.REST_DESCENTS
    -- Never shortens a stay already being served: a body put back in bed is in for the longer of the two.
    player.resting[charId] = math.max(owed, Injury.resting(player, charId))
    return player.resting[charId]
end

-- A NIGHT PASSES -- which in this game means the company walked into the stair (models/gate.lua's
-- Gate.night). Ticks every stay down one and mends whoever has served theirs.
--
-- Mends ONE injury per completed stay rather than clearing the body: the stay was bought against a
-- single injury (Injury.rest multiplies by the count), so a body that went in carrying three comes out
-- of its full term whole, and one pulled out early has simply not finished.
--
-- Returns the ids that walked out of the ward, sorted, so a caller can name them.
function Injury.tickRest(player)
    if not (player and player.resting) then return {} end
    local up = {}
    for id, left in pairs(player.resting) do
        local now = left - 1
        if now <= 0 then
            player.resting[id] = nil
            player.injuries = player.injuries or {}
            player.injuries[id] = nil -- the full term sets every bone that bought it
            up[#up + 1] = id
        else
            player.resting[id] = now
        end
    end
    Injury.stamp(player)
    table.sort(up)
    return up
end

-- (INJURY.CLEAR IS DELETED. It set every bone on the player at once, free, and both town screens called
-- it on the way in -- so an expedition's damage ended the moment anybody was standing above ground.
-- The Ward replaced it on 2026-09-16 (see the block above): mending is still free, but it is a thing
-- you go and do rather than a thing that happens to you, because an injury that evaporates on arrival
-- cannot be taught, cannot be decided about, and left the room the tutorial points at with no job.
--
-- Deleted rather than parked, because a "clear the whole ledger" call is exactly the shape somebody
-- reaches for when a screen wants the old behaviour back, and the point is that no screen should.
-- Injury.tickRest is what ends a stay now, and Injury.treat is what ends one early.)

-- Everyone on the roster carrying at least one, as { { char, count }, ... } in roster order. What the
-- party sheet walks, and what the controls that bind bones ask before they draw.
function Injury.injured(player)
    local out = {}
    for _, char in ipairs((player and player.roster) or {}) do
        local n = Injury.count(player, char.id)
        if n > 0 then out[#out + 1] = { char = char, count = n } end
    end
    return out
end

-- ...and the subset of those who have not been SEEN TO yet: injured, and not already lying up for it.
--
-- The distinction is invisible in this file's own machinery -- a resting body is still injured, and
-- Injury.rest deliberately drops no count (the stay is served by descending, Injury.tickRest) -- but it
-- is the only honest way to ask "is there anything left to do about this", which is a question two
-- surfaces ask and must not answer differently:
--
--   states/hub.lua        the first morning's flag is spent when it is empty (introAdvance)
--   ui/panels/ward.lua    ...and rings the rows of whoever is first in it while it is not
--
-- Written once here rather than twice there, because a city that thinks the lesson landed and a panel
-- still pointing at a row are the same bug seen from two screens.
function Injury.unattended(player)
    local out = {}
    for _, entry in ipairs(Injury.injured(player)) do
        if Injury.resting(player, entry.char.id) <= 0 then out[#out + 1] = entry end
    end
    return out
end

return Injury
