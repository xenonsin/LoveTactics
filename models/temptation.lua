-- The Crown's offer, the companion's resolve, and the three ways a class line can end.
--
-- Every general in the game was a human who said yes to the Demon Lord (docs/story.md, "Every general
-- is a fallen human"). The finale already says the unsayable half out loud -- "Seven people said yes to
-- it. That part does not come off." -- but says it about other people. This model is what makes it
-- about the player: each of a line's ten quests carries an offer, and what the player answers decides
-- whether that line's companion is still beside them at the Gate, and which side of the board she is
-- standing on when the Crown reaches for a name.
--
-- TWO AXES, NOT ONE. Taking a bargain and talking your companion into it are different acts, and the
-- whole design turns on the difference:
--
--   effect = { take = "bastion", grant = "...", gold = 300 }   -- you accepted. taken + 1
--   effect = { press = "bastion" }                             -- you argued HER into it. pressed + 1
--
-- A choice may set both, either, or neither, and `press` is only ever authored where the companion is
-- actually in the scene to be pressed. Refusing grants nothing at all -- a temptation that costs the
-- player nothing to decline is not a temptation, so every `take` rides with a real payload.
--
-- THE THREE OUTCOMES, resolved when a line's slot 10 completes (`endsLine` on the quest):
--
--   taken <= 3                    -> HELD.  She keeps her virtue and refuses the dead general's relic.
--   taken >= 4, pressed*2 <  taken -> LEFT.  You did it over her objection more often than with her,
--                                    and she will not follow you any further. Off the roster for good;
--                                    her bound signature relic walks out on her body.
--   taken >= 4, pressed*2 >= taken -> CAVED. You brought her along at least half the time. She stays,
--                                    puts the relic on, and is STRONGER for it. Nothing bad happens.
--                                    Nothing bad happens for another twenty hours.
--
-- The counts are cumulative over the whole line and are never walked back. That is deliberate: a
-- player who takes five early and refuses five late has still taken five, and the line's slot 7 says
-- so to their face while there is still road left (docs/temptation.md, "How the player reads it").
--
-- WHY THE OUTCOME IS A FLAG. `resolve` stamps `player.flags` rather than storing an outcome field,
-- because a flag is the one thing every downstream surface can already read: a scene block gates on
-- `when = { flag = "caved_bastion" }` with no new grammar, and the ledger below stays a pair of counts
-- that only this file interprets. One new predicate pair (models/conversation.lua) serves the whole
-- feature.
--
-- Pure logic -- no love.graphics, no love.filesystem -- so it loads and is exercised headless. See
-- tests/temptation_spec.lua and docs/temptation.md.

local Temptation = {}

-- How many of a line's TEN offers must be accepted before the line can end in anything but `held`.
-- Authored in plain units (a count of offers, out of ten) rather than as a fraction, per the house
-- rule: the knob is a number the author can hold in their head, and the arithmetic that consumes it
-- stays in the solver. Four is a third of the line and change -- enough that nobody arrives here by
-- accident, few enough that a player who is enjoying the bargains gets there well before slot 10.
Temptation.FALL_LINE = 4

-- The outcomes, as the flag prefixes they are stamped under. `caved` and `left` are deliberately NOT
-- "fallen" or "turned": "fallen" already means a downed unit (Gula "devours the fallen") AND a pacted
-- human, and "turned" already means the blooded, the turning wardens, and a Bastion quest title. One
-- word per mechanic, and these two words were free.
Temptation.HELD = "held"
Temptation.LEFT = "left"
Temptation.CAVED = "caved"

-- The ledger for one line, minted on demand. Never returns nil, so a caller can read `.taken` off a
-- line nobody has been offered anything in.
local function ledgerFor(player, vendorId, create)
    if not (player and vendorId) then return { taken = 0, pressed = 0 } end
    local all = player.temptation
    if not all then
        if not create then return { taken = 0, pressed = 0 } end
        all = {}
        player.temptation = all
    end
    local ledger = all[vendorId]
    if not ledger then
        if not create then return { taken = 0, pressed = 0 } end
        ledger = { taken = 0, pressed = 0 }
        all[vendorId] = ledger
    end
    ledger.taken = ledger.taken or 0
    ledger.pressed = ledger.pressed or 0
    return ledger
end

-- Read-only view of a line's counts. `Temptation.counts(player, "bastion").taken`.
function Temptation.counts(player, vendorId)
    local ledger = ledgerFor(player, vendorId, false)
    return { taken = ledger.taken or 0, pressed = ledger.pressed or 0 }
end

-- Record one answer. `kind` is "take" or "press"; a single choice commonly records both, in which case
-- StoryEffect calls this twice. Unknown kinds are ignored rather than raising -- this is reached from
-- authored data, and the loud check for a mistyped key belongs in the extractor's effect whitelist and
-- in tests/temptation_spec.lua, where an author will actually see it.
function Temptation.record(player, vendorId, kind)
    if not (player and vendorId) then return end
    local ledger = ledgerFor(player, vendorId, true)
    if kind == "take" then
        ledger.taken = ledger.taken + 1
    elseif kind == "press" then
        ledger.pressed = ledger.pressed + 1
    end

    -- Stamp `breaking_<vendorId>` the moment a line passes the point where it can still end in `held`.
    -- This is what lets a SCENE ask the question -- `when = { flag = "breaking_bastion" }` -- without a
    -- new predicate that reaches into the counts, and it is how slot 7 knows to give the player the one
    -- plain warning they get (docs/temptation.md, "How the player reads it").
    --
    -- Set and never cleared, because the counts it reflects are never walked back. A line that crosses
    -- and is then refused for the rest of its run still crossed, and the warning was still owed.
    if Temptation.isBreaking(player, vendorId) then
        player.flags = player.flags or {}
        player.flags["breaking_" .. vendorId] = true
    end
end

-- What a line's counts come to, WITHOUT recording anything. This is the whole rule, in one place, so
-- the spec can walk the boundary and the slot-7 warning scene can ask the same question the slot-10
-- resolution will answer.
function Temptation.outcomeFor(taken, pressed)
    taken, pressed = taken or 0, pressed or 0
    if taken < Temptation.FALL_LINE then return Temptation.HELD end
    -- "at least half the time" -- doubled rather than divided so this stays integer arithmetic and an
    -- odd count rounds the way the sentence reads (5 taken needs 3 pressed, not 2.5).
    if pressed * 2 >= taken then return Temptation.CAVED end
    return Temptation.LEFT
end

-- Where a line stands right now, as an outcome string. Called by the slot-7 warning scene through
-- `Temptation.isBreaking` below and by `resolve` at slot 10; a line nobody has answered reads `held`.
function Temptation.standing(player, vendorId)
    local ledger = ledgerFor(player, vendorId, false)
    return Temptation.outcomeFor(ledger.taken, ledger.pressed)
end

-- Is this line already past the point where it can end in `held`? The one question the slot-7 beat
-- asks, and the reason it is a function rather than a comparison written out at the call site: the
-- warning must fire on exactly the condition that will decide the line, or it is a lie.
function Temptation.isBreaking(player, vendorId)
    return Temptation.standing(player, vendorId) ~= Temptation.HELD
end

-- Settle a line. Stamps `<outcome>_<vendorId>` on player.flags and returns the outcome string.
--
-- Deliberately does NOT release a companion who left: the outro scene she says goodbye in has not
-- played yet, and `when = { has = ... }` would drop her own farewell out of it. The flag is set here so
-- the outro can gate on it; states/game.lua calls Temptation.settle below once that scene is done.
--
-- Idempotent by the flag: a line already resolved is left exactly as it was, so a repeated
-- Quest.complete (or a save reloaded onto the same quest) cannot re-decide someone's fate.
function Temptation.resolve(player, vendorId)
    if not (player and vendorId) then return nil end
    player.flags = player.flags or {}
    for _, outcome in ipairs({ Temptation.HELD, Temptation.LEFT, Temptation.CAVED }) do
        if player.flags[outcome .. "_" .. vendorId] then return outcome end
    end
    local outcome = Temptation.standing(player, vendorId)
    player.flags[outcome .. "_" .. vendorId] = true
    return outcome
end

-- Has this line been resolved, and how? nil if its slot 10 has not been completed.
function Temptation.resolved(player, vendorId)
    if not (player and vendorId and player.flags) then return nil end
    for _, outcome in ipairs({ Temptation.HELD, Temptation.LEFT, Temptation.CAVED }) do
        if player.flags[outcome .. "_" .. vendorId] then return outcome end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Who is where, once the lines are resolved
-- ---------------------------------------------------------------------------

-- Every line's companion, keyed by the vendor whose line earns her. Authored here rather than derived,
-- for the same reason a quest names its sponsor rather than inferring one: the pairing is a design
-- fact from docs/story.md ("The other seven" -- a general and her foil are the same wound with two
-- answers), it is stated nowhere else in data, and a table a spec can walk is worth more than a
-- convention a spec can only hope for. tests/temptation_spec.lua checks every id on both sides.
--
-- Rowan is the Bastion's even though she is earned in the prologue rather than off its board: the line
-- she answers is sloth's, and that is what this table is about.
Temptation.COMPANIONS = {
    bastion       = "character_rowan",
    colosseum     = "character_saber",
    cathedral     = "character_amana",
    hunters_lodge = "character_kaya",
    arcanum       = "character_gyeom",
    undercroft    = "character_clem",
    alchemist     = "character_ren",
}

-- The order lines are read in wherever "all of them" has to become a list -- the Gate's shade order,
-- and any sweep that must not depend on `pairs`. Fixed, because a fight that summons your dead friends
-- in hash order is a fight that plays differently on two machines for no reason (see
-- tests/determinism_spec.lua for the same rule applied to combat).
Temptation.LINES = {
    "colosseum", "cathedral", "hunters_lodge", "bastion", "arcanum", "undercroft", "alchemist",
}

-- The blueprint a caved companion fights as. A plain id convention rather than a field on her
-- blueprint, so the caved form and the person are two files that never have to know about each other.
function Temptation.cavedId(charId)
    return charId and (charId .. "_caved") or nil
end

-- Every companion who caved, as blueprint ids, in Temptation.LINES order.
function Temptation.caved(player)
    local out = {}
    for _, vendorId in ipairs(Temptation.LINES) do
        if Temptation.resolved(player, vendorId) == Temptation.CAVED then
            local charId = Temptation.COMPANIONS[vendorId]
            if charId then out[#out + 1] = Temptation.cavedId(charId) end
        end
    end
    return out
end

-- The names the Hollow Crown reaches for as it fails, longest-standing debt first: everyone you
-- spoiled, and then the generals to fill out the three thresholds that actually fire.
--
-- `fallback` is the curated general trio the trait used to hold as a static list, passed in rather than
-- required here so this model never reaches into data/ -- and so the trait file stays the place its own
-- casting is authored (data/traits/trait_hollow_crown.lua).
--
-- Companions first is the whole point. The Crown's own dead are a rerun; the woman standing on your
-- side of the board is not.
function Temptation.shades(player, fallback, count)
    count = count or 3
    local out = Temptation.caved(player)
    for _, id in ipairs(fallback or {}) do
        if #out >= count then break end
        out[#out + 1] = id
    end
    -- Trim: three thresholds fire, so a save with five caved companions still only wears three.
    while #out > count do table.remove(out) end
    return out
end

-- Release everyone whose line ended in `left`, once the scene that says so has finished playing.
-- Called from states/game.lua after a slot-10 outro, never from Quest.complete -- see `resolve` above
-- for why the two are separate beats. Returns the list of ids actually released.
function Temptation.settle(player)
    if not player then return {} end
    local Player = require("models.player")
    local released = {}
    for _, vendorId in ipairs(Temptation.LINES) do
        if Temptation.resolved(player, vendorId) == Temptation.LEFT then
            local charId = Temptation.COMPANIONS[vendorId]
            if charId and Player.release(player, charId) then
                released[#released + 1] = charId
            end
        end
    end
    return released
end

return Temptation
