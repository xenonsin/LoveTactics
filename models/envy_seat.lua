-- ENVY'S SEAT, THE ONE-OFF FAMILIES (slice C of "Envy's Bestiary", reviewed 2026-10-01..03). Five bodies on the
-- Ribstone Waste's second floor, each its own family, and three of them about copying:
--
--   THE HOMUNCULUS   a made thing with a red stone for a heart. It carries 3 Red Stone; a killing blow consumes
--                    one instead, and it stands back up at full health at the start of its next turn. While it
--                    holds any it heals a tenth a turn. Unclosing stops both the healing and the getting up.
--   THE BRAZEN HEAD  Friar Bacon's head, which speaks three times, each a wind-up a shove breaks: Time is (its
--                    side Hasted), Time was (its side heals what it lost since the last utterance), Time is past
--                    (it shatters, and every foe within 3 is Stunned).
--   THE ECHO         a foe casts an ability within 3 of it, and it repeats the blow at half power, from its own
--                    tile, at the caster.
--   ARACHNE          weaves every ability the company casts in her sight; at 3 threads of one, she casts it back.
--   THE PENITENTS    blind, they strike the last of the company to act, and Invisible, illusions and Blind
--                    mean nothing to them.
--
-- Pure logic, headless-safe. Combat, Status and Trait are reached lazily: this file is required from inside
-- models/trait.lua and models/ai.lua at blow time, and both of those are required by Combat.

local EnvySeat = {}

local function name(u) return (u and u.char and u.char.name) or "It" end

-- ------------------------------------------------------------------------------------- the red stone

EnvySeat.RED_STONES = 3      -- what a Homunculus opens the fight holding
EnvySeat.RED_STONE_REGEN = 0.1 -- the share of its health it heals a turn while it holds any

-- A blow would fell `unit`, which carries a red stone rule (`redStone` on its trait). Consume one Red Stone and
-- keep it at 1, or answer false and let it fall. Asked from Trait.trySurvive on a REAL lethal blow only.
--
-- Two bodies carry the rule and they part on what happens next:
--   * the Homunculus (`redStoneRises`) is down until its next turn, when it stands back up whole -- and an
--     Unclosing wound refuses it outright, since a body that cannot be healed cannot be put back together;
--   * the Stone Heart's bearer (the drop) is simply left at 1, which is all the item promises.
function EnvySeat.onLethal(combat, unit)
    local Trait = require("models.trait")
    local Status = require("models.status")
    local rule = Trait.flag(unit, "redStone")
    if not rule or Status.stacksOf(unit, "status_red_stone") < 1 then return false end
    local rises = rule.def.redStoneRises
    if rises and Status.blocksHealing(unit) then return false end
    Status.spendStacks(combat, unit, "status_red_stone", 1)
    unit.char.stats.health.current = 1
    local Combat = require("models.combat")
    if rises then
        unit.redStoneFallen = true
        Combat.logEvent(combat, "action", string.format("%s falls, and its red stone cracks.", name(unit)), unit)
    else
        Combat.logEvent(combat, "action", string.format("%s's red stone takes the blow.", name(unit)), unit)
    end
    return true
end

-- The top of a Homunculus's own turn: a fallen one stands back up whole, and one still holding a stone heals a
-- tenth. Both go through Combat.applyHeal, the one funnel an Unclosing wound shuts.
function EnvySeat.redStoneTurn(combat, unit)
    if not (unit and unit.alive) then return end
    local Combat = require("models.combat")
    local max = Combat.unreservedMax(unit.char, "health")
    if unit.redStoneFallen then
        unit.redStoneFallen = nil
        local healed = Combat.applyHeal(combat, unit, max)
        if healed > 0 then
            Combat.logEvent(combat, "action", string.format("%s stands back up.", name(unit)), unit)
        end
        return
    end
    if require("models.status").stacksOf(unit, "status_red_stone") > 0 then
        Combat.applyHeal(combat, unit, math.max(1, math.floor(max * EnvySeat.RED_STONE_REGEN + 0.5)))
    end
end

-- ------------------------------------------------------------------------------------- the brazen head

-- The utterance the head speaks next, in order, by how many it has finished. A shoved wind-up finishes nothing,
-- so the same words are tried again.
EnvySeat.UTTERANCES = { "ability_time_is_spoken", "ability_time_was_spoken", "ability_time_is_past_spoken" }

function EnvySeat.spoken(unit) return (unit and unit.utterances) or 0 end

-- Is `item` the utterance `unit` is due to speak? The `usable` gate every utterance shares.
function EnvySeat.dueUtterance(unit, item)
    return EnvySeat.UTTERANCES[EnvySeat.spoken(unit) + 1] == (item and item.id)
end

-- Write down what every body on the head's side stands at now. Time Was reads it back: it heals what each has
-- lost since the last utterance. Called at the bell and after every utterance lands, from the head's organ.
function EnvySeat.markTime(combat, head)
    local ledger = {}
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side == head.side then ledger[u] = u.char.stats.health.current end
    end
    head.brazenLedger = ledger
end

-- What `u` has lost since the head last spoke, read off the ledger (0 for a body that arrived since).
function EnvySeat.lostSince(head, u)
    local was = head and head.brazenLedger and head.brazenLedger[u]
    if not was then return 0 end
    return math.max(0, was - u.char.stats.health.current)
end

-- The head's whole turn: speak the next utterance, on itself. Nothing else is in its mouth.
function EnvySeat.headPlan(combat, unit)
    local Trait = require("models.trait")
    if unit.side == "party" or not Trait.flag(unit, "brazenHead") or unit.channel then return nil end
    local Combat = require("models.combat")
    local want = EnvySeat.UTTERANCES[EnvySeat.spoken(unit) + 1]
    for _, item in ipairs(require("models.character").eachItem(unit.char)) do
        if item.id == want and not Combat.itemBlockReason(unit, item) then
            return { item = item, tx = unit.x, ty = unit.y, reason = "the head speaks" }
        end
    end
    return nil
end

-- ------------------------------------------------------------------------------------- casting it back

-- Is `item` an ability whose blow can be thrown again? An ability (never a weapon swing) that declares damage.
-- What does not wound -- a heal, a ward, a debuff -- has nothing to repeat at the caster.
function EnvySeat.repeatable(item)
    -- `and` hands back `false` for a non-ability, not nil, so the guard asks for a table rather than for non-nil.
    local ab = item and item.type == "ability" and item.activeAbility
    return type(ab) == "table" and type(ab.damage) == "number" and ab.damage > 0
end

-- `from` throws the blow of `item` at `at`, from its own tile, at `scale` of the ability's own damage. A
-- repeat, not a cast: it costs nothing, ends no turn and sets off no onAnyCast, so an Echo cannot echo an
-- Arachne, nor itself.
function EnvySeat.castBack(combat, from, at, item, scale)
    if not (from and from.alive and at and at.alive and EnvySeat.repeatable(item)) then return 0 end
    local amount = math.max(1, math.floor(item.activeAbility.damage * (scale or 1)))
    return require("models.combat").dealDamage(combat, from, at, item, { amount = amount })
end

-- THE ECHO: a foe of the bearer cast `item` within 3. Repeat its blow at half power, at the caster.
EnvySeat.ECHO_REACH = 3
function EnvySeat.echo(combat, echo, caster, item)
    if not (echo and echo.alive and caster and caster.alive) or caster.side == echo.side then return false end
    if not EnvySeat.repeatable(item) then return false end
    local Combat = require("models.combat")
    if Combat.unitGap(echo, caster) > EnvySeat.ECHO_REACH then return false end
    Combat.logEvent(combat, "action", string.format("%s repeats %s.", name(echo), item.name or "it"),
        { echo, caster })
    EnvySeat.castBack(combat, echo, caster, item, 0.5)
    return true
end

-- ARACHNE: a foe cast `item` in her sight. One thread on her tapestry; at the third of one ability she throws
-- it back at the caster, whole, once. The count rides her Woven badge so the readout is the record.
EnvySeat.THREADS = 3
function EnvySeat.weave(combat, weaver, caster, item)
    if not (weaver and weaver.alive and caster and caster.alive) or caster.side == weaver.side then return false end
    if not EnvySeat.repeatable(item) then return false end
    local Combat = require("models.combat")
    if not Combat.unitsSighted(combat, weaver, caster) then return false end
    local Status = require("models.status")
    local st = Status.get(weaver, "status_woven") or Status.apply(combat, weaver, "status_woven", { magnitude = 0 })
    if not st then return false end
    st.threads = st.threads or {}
    st.cast = st.cast or {}
    local n = (st.threads[item.id] or 0) + 1
    st.threads[item.id] = n
    local most = 0
    for _, v in pairs(st.threads) do if v > most then most = v end end
    st.magnitude = most
    if n >= EnvySeat.THREADS and not st.cast[item.id] then
        st.cast[item.id] = true
        Combat.logEvent(combat, "action", string.format("%s has woven %s, and casts it back.", name(weaver),
            item.name or "it"), { weaver, caster })
        EnvySeat.castBack(combat, weaver, caster, item, 1)
    end
    return true
end

-- ------------------------------------------------------------------------------------- the penitents

-- Blind, they hunt by ear: the last foe to finish a turn is the one they strike. Written by their organ on every
-- turn's end, read here. Invisible is no cover (Combat.useItem does not refuse an Invisible aim, only the
-- target lists do, and this plan does not read them), and a decoy never takes a turn, so it is never heard.
function EnvySeat.penitentPlan(combat, unit)
    local Trait = require("models.trait")
    if unit.side == "party" or not Trait.flag(unit, "huntsByEar") then return nil end
    local tt = unit.lastFoeToAct
    if not (tt and tt.alive and tt.side ~= unit.side) or tt.decoyOf or tt.incapacitated then return nil end
    local Combat = require("models.combat")
    local weapon = Combat.defaultWeapon(unit.char)
    local ab = weapon and weapon.activeAbility
    if not ab or Combat.itemBlockReason(unit, weapon) then return nil end
    local minRange = Combat.abilityMinRange(ab)
    local function reaches(d, x, y)
        return d >= minRange and d <= Combat.abilityRange(combat, unit, ab, x, y)
            + Combat.adjacencyRangeBonus(unit.char, weapon)
    end
    if reaches(Combat.unitGap(unit, tt), unit.x, unit.y) then
        local cx, cy = Combat.nearestCell(unit.x, unit.y, tt)
        return { item = weapon, tx = cx, ty = cy, reason = "hunts by ear" }
    end
    local best, closest
    for _, node in ipairs(Combat.reachableList(combat, unit)) do
        local d, cx, cy = Combat.reachFrom(unit, node.x, node.y, tt)
        if reaches(d, node.x, node.y) and (not best or node.steps < best.steps) then
            best = { x = node.x, y = node.y, tx = cx, ty = cy, steps = node.steps }
        end
        if not closest or d < closest.d or (d == closest.d and node.steps < closest.steps) then
            closest = { x = node.x, y = node.y, d = d, steps = node.steps }
        end
    end
    if best then
        return { move = { x = best.x, y = best.y }, item = weapon, tx = best.tx, ty = best.ty, reason = "hunts by ear" }
    end
    if closest and closest.d < Combat.unitGap(unit, tt) then
        return { move = { x = closest.x, y = closest.y }, reason = "hunts by ear" }
    end
    return nil
end

return EnvySeat
