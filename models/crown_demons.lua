-- THE CROWN'S DEMONIC CREATURES AND ITS DEATH KNIGHT ("The Crown's Bestiary", slice B, approved 2026-10-09). Five
-- bodies on the floor under every circle, and each rule here is carried so the body's drop runs the same code
-- pointed the other way:
--
--   THE OFFER (Pit Imp)          its sting lays Blood Debt: +5 damage for 2 turns, and when it runs out the body
--                                takes a third of all the damage it dealt under it. Cured off, it is never paid.
--   DRAG BELOW (Chain Fiend)     a hooked chain at 3 pulls the struck body in beside the fiend and Roots it there.
--                                The pull is Combat.pull's, so it stops on a body in the line.
--   FIT THE CRIME (Erinys)       her arrow lands the status that answers what the target did on its last turn.
--   HELLFIRE RING / DEATH THROES the Balor's telegraphed ring, and the blast it throws when it dies.
--   BULWARK OF THE FALLEN        an ally falling within 3 of the Death Knight closes over it as a Physical Barrier
--   (Death Knight)               worth half that ally's max health.
--
-- BLOOD DEBT IS NOT OWED. Greed's Owed ("In debt") makes every blow on the bearer land harder per stack; Blood Debt
-- charges the bearer for the blows IT landed. One is a debt you are hit with, the other a debt you run up.
--
-- A PHYSICAL BARRIER WORTH AN AMOUNT. The barrier status counts blows (`magnitude`), and the Bulwark is a size in
-- health, so a barrier this file grants carries a `pool` on the instance: physical damage is paid out of it after
-- armour (as the Surfeit shield is) until it is spent, and magic goes straight past it, as it goes past any
-- Physical Barrier. Status.barrierAgainst skips a pooled barrier, so it never eats a blow whole.
--
-- Pure logic, headless-safe. Combat and Status are reached lazily: both call into this file at blow time.

local Crown = {}

local function Combat() return require("models.combat") end
local function Status() return require("models.status") end

local function nameOf(u) return (u and u.char and u.char.name) or "Unit" end

local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do
        if t == want then return true end
    end
    return false
end

-- ------------------------------------------------------------------------------------------- Blood Debt

Crown.DEBT = "status_blood_debt"
Crown.DEBT_SHARE = 1 / 3

-- `attacker` just dealt `dmg`. If it is under Blood Debt, the debt grows by what it dealt. Called from
-- Combat.dealFlatDamage, the one funnel every wound runs through.
function Crown.noteDealt(attacker, dmg)
    if not (attacker and attacker.statuses and (dmg or 0) > 0) then return end
    local debt = Status().get(attacker, Crown.DEBT)
    if debt then debt.dealt = (debt.dealt or 0) + dmg end
end

-- What a Blood Debt of `dealt` charges back when it comes due.
function Crown.debtOwed(dealt)
    return math.floor((dealt or 0) * Crown.DEBT_SHARE)
end

-- Blood Debt's onExpire. Only a debt that RAN OUT is paid: a Cure removes it with time still left on it, and that
-- is the counter the review names. Returns the damage charged.
function Crown.settleDebt(ctx)
    local s, u = ctx.status, ctx.unit
    if not (s and u and u.alive) or (s.remaining or 0) > 0 then return 0 end
    local owed = Crown.debtOwed(s.dealt)
    if owed <= 0 then return 0 end
    ctx.log("status", string.format("%s's Blood Debt comes due (%d).", nameOf(u), owed), u)
    return ctx.damage(u, owed, { "debt" }, { raw = true })
end

-- -------------------------------------------------------------------------------------------- the deeds
--
-- What a body did on its own last turn, for Fit the Crime. Noted at the seams where each deed already passes
-- (Combat.useItem, Combat.moveUnit, a cast's heal), only while it is that body's turn, so an answer thrown on
-- somebody else's turn is not a deed. Stamped with the body's `turnTaken` tally: a later turn in which it did
-- nothing leaves the stamp behind, and the old deeds no longer count.

local function turnStamp(unit) return Combat().tallyCount(unit, "turnTaken") end

function Crown.noteDeed(combat, unit, deed)
    local turn = combat and combat.turn
    if not (unit and turn and turn.unit == unit) then return end
    local d = unit.deeds
    if not d or d.turn ~= turn then
        d = { turn = turn }
        unit.deeds = d
    end
    d.stamp = turnStamp(unit)
    d[deed] = true
end

-- The deeds of `unit`'s last turn, as a set ({ attacked, cast, moved, healed }); empty when it has done nothing.
function Crown.lastDeeds(unit)
    local d = unit and unit.deeds
    if not d or d.stamp ~= turnStamp(unit) then return {} end
    return d
end

-- The punishment for each crime, worst first. A body that did two things answers for the first one listed: a
-- heal and a cast are the deeds a company can least afford to lose, and moving is the deed every body commits.
Crown.CRIMES = {
    { deed = "healed", status = "status_interred" },
    { deed = "cast", status = "status_silenced" },
    { deed = "attacked", status = "status_disarmed" },
    { deed = "moved", status = "status_root" },
}

-- The status that answers `unit`'s last turn, or nil when it did nothing the list names. `skip` names deeds the
-- caller does not punish (Fury's Verdict has no answer for a heal).
function Crown.verdict(unit, skip)
    local deeds = Crown.lastDeeds(unit)
    for _, c in ipairs(Crown.CRIMES) do
        if deeds[c.deed] and not (skip and skip[c.deed]) then return c.status, c.deed end
    end
    return nil
end

-- The arrow itself, for the Erinys's bow and Fury's Verdict: strike, then land the answer if the body stands.
function Crown.fitTheCrime(fx, skip)
    local t = fx.target
    if not t then return end
    fx.damage(t)
    if not t.alive then return end
    local id = Crown.verdict(t, skip)
    if id then fx.applyStatus(t, id) end
end

-- ------------------------------------------------------------------------------------------- Drag Below

Crown.DRAG_ROOT = 5 -- one turn, at Status.TICKS_PER_TURN

-- Hook `target` in beside `fx.user` and Root it there. A pull stops on any body in the line (Combat.pull), and
-- the Root lands wherever the hooked body ended up: it was caught even if it did not travel.
function Crown.dragBelow(fx, target)
    if not (target and target.alive) then return end
    fx.pull(target)
    if target.alive then fx.applyStatus(target, "status_root", { duration = Crown.DRAG_ROOT }) end
end

-- ----------------------------------------------------------------------------------------- the Balor

-- The cells within `radius` of `unit`'s whole footprint, the footprint itself left out: what the Hellfire Ring
-- burns. Measured from every cell of a wide body, so a 2x2 Balor's ring is the same depth on all four sides.
function Crown.ringCells(unit, radius)
    local out = {}
    if not unit then return out end
    local w, h = unit.w or 1, unit.h or 1
    for x = unit.x - radius, unit.x + w - 1 + radius do
        for y = unit.y - radius, unit.y + h - 1 + radius do
            local gap = Combat().cellGap(x, y, unit)
            if gap >= 1 and gap <= radius then out[#out + 1] = { x = x, y = y } end
        end
    end
    return out
end

-- Every body within `radius` of `unit`'s footprint, either side, the unit itself left out.
function Crown.bodiesWithin(combat, unit, radius)
    local out = {}
    for _, u in ipairs((combat and combat.units) or {}) do
        if u ~= unit and u.alive and not Combat().isOffTile(u) and Combat().unitGap(unit, u) <= radius then
            out[#out + 1] = u
        end
    end
    return out
end

-- DEATH THROES (and Last Breath, the same blast handed over): the fallen body bursts, and every body within its
-- radius takes the fire, its own side included.
function Crown.deathThroes(ctx)
    local u = ctx.unit
    if not u then return 0 end
    local radius, blast = ctx.param("radius", 3), ctx.param("magnitude", 20)
    ctx.burst(u.x, u.y, { "fire" })
    local n = 0
    for _, other in ipairs(Crown.bodiesWithin(ctx.combat, u, radius)) do
        ctx.damage(other, blast, { "fire" })
        n = n + 1
    end
    return n
end

-- ------------------------------------------------------------------------------- Bulwark of the Fallen

Crown.BULWARK = "status_physical_barrier"

-- Close `amount` of Physical Barrier over `unit`. A pooled barrier already worn grows by it.
function Crown.grantBarrier(combat, unit, amount)
    if not (unit and unit.alive) or (amount or 0) <= 0 then return nil end
    local held = Status().get(unit, Crown.BULWARK)
    local pool = amount + ((held and held.pool) or 0)
    local st = Status().apply(combat, unit, Crown.BULWARK, { applier = unit })
    if st then st.pool = pool end
    return st
end

-- An ally of `bearer` fell. Within `reach`, its armour closes over the bearer: `share` of its max health.
function Crown.bulwark(combat, bearer, fallen, share, reach)
    if not (bearer and bearer.alive and fallen and fallen ~= bearer and fallen.side == bearer.side) then return 0 end
    if Combat().unitGap(bearer, fallen) > (reach or 3) then return 0 end
    local hp = fallen.char and fallen.char.stats and fallen.char.stats.health
    local amount = math.floor(((type(hp) == "table" and hp.max) or 0) * (share or 0.5))
    if amount <= 0 then return 0 end
    Combat().logEvent(combat, "status", string.format("%s's armour closes over %s (%d).",
        nameOf(fallen), nameOf(bearer), amount), { bearer, fallen })
    Crown.grantBarrier(combat, bearer, amount)
    return amount
end

-- Pay a physical wound out of `target`'s pooled barrier, after armour. Magic passes it by. Returns how much of
-- `dmg` it covered; the barrier goes when the pool is spent.
function Crown.soakBarrier(combat, target, dmg, tags)
    if not dmg or dmg <= 0 or hasTag(tags, "magical") then return 0 end
    local st = target and target.statuses and Status().get(target, Crown.BULWARK)
    if not (st and st.pool) then return 0 end
    local covered = math.min(dmg, st.pool)
    st.pool = st.pool - covered
    if st.pool <= 0 then Status().remove(combat, target, Crown.BULWARK) end
    if combat then
        Combat().logEvent(combat, "status", string.format("%s's barrier takes %d of the blow%s.", nameOf(target),
            covered, st.pool > 0 and string.format(" (%d left)", st.pool) or ""), target)
    end
    return covered
end

return Crown
