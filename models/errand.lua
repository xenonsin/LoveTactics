-- COMPANION POSTINGS: the six bodies standing one to a floor of the rift, and the one piece of work
-- each of them asks for before they will walk out with you.
--
-- THIS FILE USED TO BE A LADDER, and most of it is gone. Every house posted a line of errands -- its
-- opener plus one job per discipline gate -- and running them was what climbed that house's shelf. The
-- houses are classes now (docs/classes.md): a class is something a BODY climbs by playing its gear
-- (models/class.lua's Class.classLevel), not a room you unlock and not a shelf you buy a rung
-- of at a time. So there is no ladder left to lay, no door left to open, and no shop left to ask from.
--
-- WHY THE FILE SURVIVES AT ALL. One thing the ladder carried was worth keeping and had nowhere else to
-- go: it was the only place the game said "there is a reason to go back down, and here is exactly what
-- it is". The companions carry that now, and they say it underground where the work is.
--
-- A RECRUIT IS TWO BEATS, and the second is the point:
--
--   1. YOU MEET THEM     they are standing at a dead end on one of the first floors, as a stop with no
--                        fight in it (Descent.floorObjectives seats them). Talking is free.
--   2. THEY ASK          accepting marks one more end on the SAME floor and puts a row on the
--                        checklist. Clear it and they join.
--
-- The second beat is what makes the meeting cost something, and it costs the one thing a floor actually
-- charges: how much more of it are you willing to walk. No fight is added to do it -- the mark lands on
-- ground the floor already carved -- so the whole decision is the greed dial the descent is built
-- around, with a body attached to it. Walk past and they keep standing there; Descent.enterFloor puts a
-- cleared board back exactly as it stood, dead end and all, so climbing back for one is a price rather
-- than a lock-out.
--
-- WHAT THE ASK IS, and why almost none of this is new content: it is that house's own `slot_01`, the
-- quest authored back when the Quest Board posted them. Those blueprints already carry everything a
-- posting needs -- a name, a description, the scene where they ask and the scene where they thank you,
-- the fight itself, and what it pays -- and `rewardCharacter` is how the companion actually joins, which
-- is the same route Saber has always arrived by.
--
-- Pure model: no love.graphics, no state switching. states/game.lua seats and resolves them.

local Quest = require("models.quest")

local Errand = {}

-- THE ASK A HOUSE'S COMPANION MAKES: that class's own `slot_01`, or nil if it has none.
--
-- Named for the slot rather than taken off the front of a sorted list, and that is not a nicety. The
-- ids sort by alphabet, so the Colosseum's line led with `..._champions_challenge` and the Crucible's
-- with `..._apothecary_ren` -- a capstone bout and somebody else's recruit, neither of which is the job
-- a companion introduces themselves with.
function Errand.opener(vendorId)
    if not vendorId then return nil end
    local id = "quest_" .. vendorId .. "_slot_01"
    local def = Quest.defs[id]
    if def and def.map and def.map.objective then return id end
    return nil
end

-- WHO A HOUSE'S POSTING ACTUALLY HANDS OVER, read off the opener's own `rewardCharacter` -- the field
-- that IS the recruit -- rather than off the vendor's `companion`, which only says whose house it is.
--
-- The two disagree for exactly one house and the disagreement was live. The Bastion names Rowan, and
-- Rowan is sworn in the prologue (data/player.lua's startingRoster), so her opener pays no character:
-- there is nobody to hand over. Gating on `companion` seated a recruitment posting for a body already
-- standing in the party, at a dead end the company had to walk to, ending in a fight that recruited
-- nobody. Gating on the grant means that house simply posts nothing, with no special case anywhere.
function Errand.companionOf(vendorId)
    local opener = Errand.opener(vendorId)
    local def = opener and Quest.defs[opener]
    return def and def.rewardCharacter or nil
end

-- Every class that posts a companion, as a set. Data-derived and player-independent, so the run's deal
-- (Descent.openersAt) and the seating (Descent.floorObjectives) cannot disagree about who is out there.
function Errand.houses()
    local out = {}
    for vendorId in pairs(require("models.vendor").defs) do
        if Errand.companionOf(vendorId) then out[vendorId] = true end
    end
    return out
end

-- Has this companion's ask been finished -- which is to say, have they joined?
--
-- The name is what it was when this asked whether a shop's door had opened, and the question has not
-- really changed: one piece of work, done or not. What changed is what it buys.
function Errand.doorOpen(player, vendorId)
    local opener = Errand.opener(vendorId)
    if not opener then return true end
    return ((player and player.completedQuests) or {})[opener] == true
end

-- The floor a companion's ask is found on: the one they were met on, which is where it was marked.
--
-- Falls back to the first floor for an ask that somehow has no record, so a posting can never point at
-- a floor that does not exist. One companion is dealt per floor (Descent.openersAt), so a run meets
-- them a floor at a time rather than all at once in the shallows.
function Errand.floorFor(player, vendorId)
    local opener = Errand.opener(vendorId)
    return (opener and ((player and player.errands) or {})[opener]) or 1
end

-- Is `questId` a companion's ask that nobody has agreed to yet?
--
-- Both ends of a recruit are seated when the floor is built (Descent.floorObjectives) -- a floor is
-- generated once and put back exactly as it stood, so there is no later moment at which a new end could
-- be carved. That means the ASK is standing on the board before the player has met the body who wants
-- it, and this is what stops the checklist promising work nobody has been asked for.
--
-- The marker stays: the floor's own fog is what keeps it a question, and a company that walks the far
-- end first simply finds the fight without knowing whose it was. What it must not do is appear on the
-- run's list of work as though it had been agreed to.
function Errand.unaskedPosting(player, questId)
    if not questId then return false end
    if ((player and player.completedQuests) or {})[questId] then return false end
    if ((player and player.errands) or {})[questId] then return false end
    for vendorId in pairs(Errand.houses()) do
        if Errand.opener(vendorId) == questId then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Taking one on
-- ---------------------------------------------------------------------------

-- Accept `errandId`, to be found on `floor`. Stored on the player as { errandId = floor } so the shop
-- can say WHICH FLOOR to look on -- an errand whose location the player has to remember is a chore
-- rather than a piece of work.
function Errand.accept(player, errandId, floor)
    if not (player and errandId) then return nil end
    player.errands = player.errands or {}
    player.errands[errandId] = floor or 1
    return floor
end

-- Every errand taken on and not yet finished, as { id, floor, def }, shallowest floor first. What the
-- shop's third tab lists and what a floor asks for when it is being built.
function Errand.open(player)
    local out = {}
    for id, floor in pairs((player and player.errands) or {}) do
        if not (player.completedQuests or {})[id] then
            out[#out + 1] = { id = id, floor = floor, def = Quest.defs[id] }
        end
    end
    -- Sorted by floor then id: `pairs` again, and a list that reorders itself between two openings of
    -- the same panel reads as a bug.
    table.sort(out, function(a, b)
        if a.floor ~= b.floor then return a.floor < b.floor end
        return a.id < b.id
    end)
    return out
end

-- The ones to seat on `floor`, as quest-shaped entries Quest.trip can build objectives from.
function Errand.onFloor(player, floor)
    local out = {}
    for _, e in ipairs(Errand.open(player)) do
        if e.floor == floor and e.def then
            local entry = {}
            for k, v in pairs(e.def) do entry[k] = v end
            entry.id = e.id
            out[#out + 1] = entry
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Meeting one on the floor
-- ---------------------------------------------------------------------------

-- WHOSE WORK IS STANDING AT THIS DEAD END, or nil when the end is not anybody's errand.
--
-- A floor's ends all look alike from the map: a marker on a dead end with a fight behind it. Two of
-- them are a house's, and until this existed the player was told so by nothing at all. The asked one
-- was at least chosen in a shop an hour ago; the OPENER was never chosen by anybody -- it is lying on
-- the floor unasked (Descent.floorObjectives), and a company that walked into it fought a siege for a
-- quartermaster they had never met and found out what it was for from a shelf that moved.
--
-- So the tile says it before the fight does (states/game.lua's askErrand), and the two kinds are told
-- apart because they are two different sentences:
--
--   asked   the house asked for this in its shop and the company came down here to find it
--   found   the house has no door yet; this is the posting that opens it
--
-- ALREADY-FINISHED READS AS NEITHER, which matters on a resumed run: a cleared cell is not re-entered,
-- but an errand can also be finished from the OTHER end (the same job seated on a floor twice over two
-- runs), and asking whether to take on work already done is a scene about nothing.
function Errand.posting(player, questId)
    if not questId then return nil end
    local def = Quest.defs[questId]
    if not (def and def.sponsor) then return nil end
    if ((player and player.completedQuests) or {})[questId] then return nil end
    local kind
    if ((player and player.errands) or {})[questId] then
        kind = "asked"
    elseif questId == Errand.opener(def.sponsor) and not Errand.doorOpen(player, def.sponsor) then
        kind = "found"
    end
    if not kind then return nil end
    return { id = questId, def = def, vendorId = def.sponsor, kind = kind }
end

-- The scene that asks, and it is the COMPANION'S -- `conversation_<vendor>_errand_<kind>`, one pair per
-- body, no generic behind them.
--
-- THERE USED TO BE TWO SCENES FOR ALL SEVEN, and they were generic on purpose: the situation was the
-- same every time -- a seal on a stone, a job nobody took -- so the house and the work were read off the
-- posting through `{house}` and `{posting}` rather than written seven times. That reasoning belonged to
-- a posting, and this is not a posting any more. What is standing at the dead end is a PERSON, asking
-- for one thing, in the only scene the game has to establish who they are before you fight beside them
-- for the rest of the run. A shared script makes six women say the same three sentences in six
-- portraits, and the one beat that introduces the roster introduces nobody.
--
-- TWO KINDS BECAUSE THE SECOND MEETING IS NOT THE FIRST. `found` is the introduction; `asked` is walking
-- back up to somebody who has already asked -- reachable whenever an agreed posting is seated again on a
-- later run (Errand.onFloor), and having them introduce themselves twice is the failure this splits.
--
-- Nil when a house has authored neither, which is a house whose companion cannot be met at all; the
-- pair is required rather than optional, and tests/companion_posting_spec.lua is what says so -- a
-- silent fall-through to shared prose is exactly what this replaced.
function Errand.postingScene(posting)
    if not (posting and posting.kind) then return nil end
    local own = "conversation_" .. tostring(posting.vendorId) .. "_errand_" .. posting.kind
    if require("models.conversation").defs[own] then return own end
    return nil
end

-- ---------------------------------------------------------------------------
-- The first-clear bonus
-- ---------------------------------------------------------------------------
--
-- AN ERRAND PAYS A BONUS THE FIRST TIME IT IS CLEARED, AND FAILING IT ONCE SPENDS THAT BONUS FOREVER.
-- The work itself is untouched: the end stays standing where it was met, the company can walk back onto
-- it, and finishing it opens the rung, hands over the goods, grants the discipline and plays the outro
-- exactly as it always did. What does not come back is the purse.
--
-- WHY THE PURSE AND NOTHING ELSE, and it is a constraint rather than a preference. An errand's
-- `rewardItems` are that slot's share of its line's quest-only shelf stock -- the pieces a vendor's
-- shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua) -- so withholding them
-- would delete items from the run rather than charge for a loss. The rung behind the job is a discipline
-- gate, and gating THAT on winning first time would shut a class out of a run over one bad fight, which
-- is the exact failure this whole model was written to undo (see the header). Gold is the one field an
-- errand carries that nothing else is standing on.
--
-- SO IT IS A DECISION AND NEVER A NEED. A player who never loses never notices this; a player who does
-- is out a purse and still has every door they were walking toward.
--
-- KEYED ON THE PLAYER RATHER THAN THE RUN, beside `errands` itself, because a descent is a thing you
-- come back from and the bonus must not quietly reappear when you do.
function Errand.fail(player, errandId)
    if not (player and errandId) then return false end
    -- A job already finished has already been paid; there is no bonus left to spend and nothing to
    -- record. Guarded here rather than at the caller so no exit can write a mark on settled work.
    if (player.completedQuests or {})[errandId] then return false end
    player.errandsFailed = player.errandsFailed or {}
    -- Returns true only on the FIRST failure, so a caller with somewhere to say it can name the loss
    -- once rather than on every attempt after.
    if player.errandsFailed[errandId] then return false end
    player.errandsFailed[errandId] = true
    return true
end

-- Has this errand already been failed -- i.e. is its first-clear bonus gone?
--
-- TWO CALLERS AND THEY MUST AGREE: the grant (states/game.lua's errand payout) and the preview
-- (models/descent.lua's Descent.objectiveReward, which draws the victory screen's reward cards). A
-- preview wider than its grant promises a payout the beat never pays, and this file has watched that
-- happen before -- the Beggar's Bowl was named after every win on a lust floor and handed over at none
-- of them. One function, asked from both sides.
function Errand.failedOnce(player, errandId)
    if not (player and errandId) then return false end
    return ((player.errandsFailed or {})[errandId]) == true
end

-- Finished. Writes the SHELF'S OWN LEDGER rather than a second one, so the stock opens by the path it
-- always did (Quest.shelfRung -> Vendor.stock), and drops the open-errand entry so the shop stops
-- listing a floor to go to.
--
-- AND DOTS WHAT IT OPENED. The shelf is diffed either side of that write and the new wares are marked
-- unseen (Quest.markOpenedStock), which is the dot the shop draws on those rows and the dot the hub
-- draws on the house's door (Vendor.hasMarkedStock). The campaign's payout seam has done this since
-- shelves started opening per quest; an errand did not, because it pays out here rather than in
-- Quest.complete -- so the one thing a house's work is FOR happened silently, in a city where the
-- player is standing in front of seven doors and cannot see which one moved.
--
-- Returns the report as a second value (nil when the errand opened nothing), so a caller with somewhere
-- to say it can name the house without diffing the shelf a third time.
function Errand.complete(player, errandId)
    if not (player and errandId) then return false end
    if (player.completedQuests or {})[errandId] then return false end
    local vendorId = (Quest.defs[errandId] or {}).sponsor
    local before = vendorId and Quest.shelf(player, vendorId)
    player.completedQuests = player.completedQuests or {}
    player.completedQuests[errandId] = true
    if player.errands then player.errands[errandId] = nil end
    -- `errandsFailed` is deliberately NOT dropped here, however tidy that would look beside the line
    -- above. The payout that follows this call is what asks Errand.failedOnce -- clearing the mark on the
    -- way past would hand the first-clear bonus to the one company that had already lost it.
    return true, Quest.markOpenedStock(player, vendorId, before)
end

return Errand
