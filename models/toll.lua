-- THE TOLLKEEPERS: the demons who keep the gates of the lower rift, on Sloth's seat ("Sloth's Bestiary", 2026-10-04,
-- slice F). They take their due in what you do, never in gold, and every rule below is a price on an act:
--
--   EXIT FEE        a body of yours that WALKS out of a Tollkeeper's reach is struck on the way out. Coming in is
--                   free, and so is being shoved out (Toll.exitFee, fired per walked tile from Combat.stepMove).
--   THE BARRIER     the Bailiff braces at the end of every turn, and its brace covers every Tollkeeper beside it
--                   until the Bailiff's own next turn. An impact blow breaks a Tollkeeper's brace, and breaking
--                   the Bailiff's opens the whole gate (Toll.barrier / Toll.release / Toll.breakBrace).
--   RIDE PAST       the Outrider charges up to 4 tiles down a lane, through every body in it, and comes out on
--                   the far side. With nowhere to come out it stops dead and is Stunned (Toll.ride).
--   WHAT IT WAS OWED a Tollkeeper that falls lets the Due out of it, and the Due goes for whoever made the kill;
--                   its blow on that body is the debt paid, and it is gone (Toll.spawnDue, weapon_dues_claws).
--   TOLL OF HOURS   an ability used within 4 of Mora costs its user its next move: Rooted on its next turn.
--   PASSAGE PAID    a body that spends a whole turn doing nothing on one of Mora's gate tiles leaves the board
--                   safe; when every living body of the company has passed, the fight is won (Toll.passedThrough,
--                   read by Combat.outcomeFor) -- and Mora, who did not fall, pays no drop.
--
-- Pure logic, headless-safe. Combat and Trait are reached lazily, as every model the combat core calls back into is.

local Status = require("models.status")

local Toll = {}

local function C() return require("models.combat") end
local function T() return require("models.trait") end

local function name(u) return (u and u.char and u.char.name) or "It" end

-- How far a ride runs, and the badge a brace wears.
Toll.RIDE_LENGTH = 4
Toll.BRACE = "status_defending"

-- Does `u` keep a gate? Every Tollkeeper carries Exit Fee on its organ, and the flag is how the rest of the line
-- recognises its own -- the Bailiff's brace covers only a body that answers to it.
function Toll.isTollkeeper(u)
    return u ~= nil and T().flag(u, "exitFee") ~= nil
end

-- ---------------------------------------------------------------------------------------------- EXIT FEE

-- How far `keeper` reaches with its default weapon from where it stands, and the dead zone inside that reach. A
-- body with no weapon (Mora, who never strikes) reaches nothing, so her Exit Fee is a rule she carries and never
-- collects.
local function reachOf(combat, keeper)
    local weapon = C().defaultWeapon(keeper.char)
    local ab = weapon and weapon.activeAbility
    if not ab then return nil end
    local range = C().abilityRange(combat, keeper, ab, keeper.x, keeper.y) + C().adjacencyRangeBonus(keeper.char, weapon)
    return weapon, range, C().abilityMinRange(ab)
end

-- `mover` just WALKED from (fromX, fromY) onto the tile it stands on. Every Tollkeeper of the other side whose reach
-- held the old tile and does not hold the new one strikes it, once, with its own weapon -- the overwatch shot's
-- shape (free: no stamina, no timeline), priced on leaving instead of on arriving. A Stunned or Frozen keeper is too
-- rattled to collect. Guarded against re-entry, so a strike that shoves somebody cannot spiral back through here.
function Toll.exitFee(combat, mover, fromX, fromY)
    if not (combat and mover and mover.alive and fromX and fromY) or combat._tollCollecting then return 0 end
    local Combat = C()
    local struck = 0
    combat._tollCollecting = true
    for _, keeper in ipairs(combat.units or {}) do
        if mover.alive and keeper.alive and keeper.side ~= mover.side and not Combat.isOffTile(keeper)
            and Toll.isTollkeeper(keeper) and not Status.disablesReactions(keeper) then
            local weapon, range, minRange = reachOf(combat, keeper)
            if weapon then
                local before = Combat.cellGap(fromX, fromY, keeper)
                local after = Combat.unitGap(mover, keeper)
                if before <= range and before >= minRange and after > range then
                    Combat.logEvent(combat, "action",
                        string.format("%s collects its fee from %s.", name(keeper), name(mover)), { keeper, mover })
                    Combat.dealDamage(combat, keeper, mover, weapon)
                    struck = struck + 1
                end
            end
        end
    end
    combat._tollCollecting = false
    return struck
end

-- ---------------------------------------------------------------------------------------------- THE BARRIER

-- Every brace `holder` lent comes down. Called as the holder's own turn opens (the brace lasts until then), when an
-- impact blow breaks the holder's brace, and harmlessly on anything else.
function Toll.release(combat, holder)
    for _, u in ipairs((combat and combat.units) or {}) do
        local st = Status.get(u, Toll.BRACE)
        if st and st.heldBy == holder and u ~= holder then Status.remove(combat, u, Toll.BRACE) end
    end
end

-- Brace `holder` and lend the brace to every ally beside it. `opts`:
--   always  brace whatever the turn was spent on (the Bailiff). Without it, only a turn that RAISED a brace lends
--           one -- a Defend, for the Bailiff's Bar -- read off the brace's own stamp against the one the holder's
--           turn opened on.
--   kin     lend only to Tollkeepers (the Bailiff covers its own line, not whatever else stands in it).
--   covers  how much defense a lent brace carries; `brace` the holder's own, when `always` raises it.
-- A lent brace is stamped `heldBy`, which is what holds it past the ally's own turn start (status_defending's
-- onTurnStart) until the holder's next turn takes it down. An ally already braced on its own, and harder, is left
-- with what it had.
function Toll.barrier(combat, holder, opts)
    if not (combat and holder and holder.alive) then return 0 end
    opts = opts or {}
    local own = Status.get(holder, Toll.BRACE)
    if opts.always then
        own = Status.apply(combat, holder, Toll.BRACE, { magnitude = opts.brace or opts.covers })
    elseif not (own and (own.serial or 0) > (holder._barrierSerial or 0)) then
        return 0
    end
    if not own then return 0 end
    local covers = opts.covers or 5
    local lent = 0
    for _, ally in ipairs(C().unitsNear(combat, holder.x, holder.y, 1)) do
        if ally ~= holder and ally.alive and ally.side == holder.side and C().unitGap(ally, holder) == 1
            and (not opts.kin or Toll.isTollkeeper(ally)) then
            local had = Status.get(ally, Toll.BRACE)
            if not (had and not had.heldBy and (had.magnitude or 0) >= covers) then
                local st = Status.apply(combat, ally, Toll.BRACE, { magnitude = covers })
                if st then st.heldBy = holder; lent = lent + 1 end
            end
        end
    end
    if lent > 0 then
        C().logEvent(combat, "defend", string.format("%s bars the gate.", name(holder)), holder)
    end
    return lent
end

-- An impact blow landed on `unit`: its brace breaks, and if it was the one holding the gate, every brace it lent
-- comes down with it.
function Toll.breakBrace(combat, unit, tags)
    local impact = false
    for _, t in ipairs(tags or {}) do if t == "impact" then impact = true end end
    if not impact then return false end
    local held = Status.has(unit, Toll.BRACE)
    if held then Status.remove(combat, unit, Toll.BRACE) end
    local lent = false
    for _, u in ipairs((combat and combat.units) or {}) do
        local st = Status.get(u, Toll.BRACE)
        if st and st.heldBy == unit and u ~= unit then lent = true end
    end
    if lent then Toll.release(combat, unit) end
    if held or lent then
        C().logEvent(combat, "status", string.format("%s's brace breaks.", name(unit)), unit)
    end
    return held or lent
end

-- ---------------------------------------------------------------------------------------------- RIDE PAST

local function sign(n)
    if n > 0 then return 1 elseif n < 0 then return -1 end
    return 0
end

-- Can a ride cross (x, y)? Ground a body could stand on and no wall or prop on it. Bodies do not bar it: a ride goes
-- through them. With no board to ask (a tooltip's stand-in) every tile is open.
local function crossable(combat, x, y)
    if not combat then return true end
    local row = combat.arena and combat.arena.tiles and combat.arena.tiles[y]
    local cell = row and row[x]
    if not (cell and cell.walkable) then return false end
    return not C().objectBlocksAt(combat, x, y)
end

-- The lane a ride runs from (x, y) one step at a time along (dx, dy): up to `length` tiles, cut at the first tile it
-- cannot cross. Each tile carries the body on it, if any; `self` is the rider, never a body in its own lane.
-- `bodyAt(x, y)` answers who stands where, so a cast and a plan read the same board through their own lens.
function Toll.lane(combat, x, y, dx, dy, length, bodyAt, self)
    local cells = {}
    for i = 1, length or Toll.RIDE_LENGTH do
        local cx, cy = x + dx * i, y + dy * i
        if not crossable(combat, cx, cy) then break end
        local body = bodyAt and bodyAt(cx, cy) or nil
        if body == self then body = nil end
        cells[#cells + 1] = { x = cx, y = cy, body = body }
    end
    return cells
end

-- Where a lane comes out: the far end of it, which lies beyond every body in it. Nil when the lane ENDS on a body --
-- a wall or another body right behind the last one in its path -- which is a ride with nowhere to come out. The
-- bodies it passes are returned with it.
function Toll.exit(cells)
    local last = 0
    local bodies, seen = {}, {}
    for i, c in ipairs(cells) do
        if c.body then
            last = i
            -- A wide body fills more than one tile of a lane and is still one body to strike.
            if not seen[c.body] then seen[c.body] = true; bodies[#bodies + 1] = c.body end
        end
    end
    if #cells == 0 or last == #cells then return nil, bodies end
    return cells[#cells], bodies
end

-- THE RIDE ITSELF, as a cast resolves it (weapon_ride_past, the Outrider's; weapon_passing_lance, its drop). Aimed
-- at a neighbouring tile, which names the lane. `opts`:
--   length      how far it runs (4)
--   foesOnly    strike only the rider's foes and ride through its allies untouched (the Lance); otherwise every
--               body in the lane is struck (the Outrider)
--   stunOnFail  a ride with nowhere to come out leaves the rider Stunned (the Outrider)
-- A ride with nowhere to come out STOPS DEAD: the rider stays where it stood and lands no blow.
function Toll.ride(fx, opts)
    opts = opts or {}
    local user = fx.user
    if not (user and fx.tx and fx.ty) then return false end
    local dx, dy = sign(fx.tx - user.x), sign(fx.ty - user.y)
    if (dx ~= 0) == (dy ~= 0) then return false end
    local cells = Toll.lane(fx.combat, user.x, user.y, dx, dy, opts.length or Toll.RIDE_LENGTH, fx.unitAt, user)
    if #cells == 0 then return false end
    local land, bodies = Toll.exit(cells)
    if not land then
        if fx.log then fx.log("action", string.format("%s has nowhere to come out.", name(user)), user) end
        if opts.stunOnFail then fx.applyStatus(user, "status_stun") end
        return false
    end
    fx.teleportUser(land.x, land.y)
    for _, b in ipairs(bodies) do
        if b.alive and b ~= user and not (opts.foesOnly and b.side == user.side) then fx.damage(b) end
    end
    return true
end

-- ---------------------------------------------------------------------------------------------- THE DUE

-- What a fallen Tollkeeper's Due goes for: whoever landed the felling blow, while it is a living foe. A burn, a trap
-- or a hazard fells a keeper with no killer, and that Due simply fights.
function Toll.killerOf(fallen)
    local killer = fallen and fallen.lastBlowBy
    if killer and killer.alive and killer ~= fallen and killer.side ~= fallen.side then return killer end
    return nil
end

Toll.DUE = "character_the_due"
-- The share of the fallen keeper's level a Due is minted at (Growth.atLevel, the shape-change's seam). Half, and
-- MEASURED: at the keeper's whole level its one blow is a collector's, and a Tollgate's four kills billed four of
-- those cost the skirmish harness three bodies and 29 unit-turns; at its blueprint's level 1 it scratches for 2 and
-- the rule is a body to ignore. At half it is a blow worth stopping, and the Tollgate runs 13 (budget 22).
Toll.DUE_LEVELLED = 0.5

-- Let `fallen`'s Due out beside it. A real body, not a conjuration, for trait_split's reason: no summoner, so
-- killUnit does not sweep it off the board with the body that let it out, and not `summoned`, so a `killAll` waits
-- for it. Hemmed in, it does not come out at all. Its blow on its debtor is the debt paid, and it goes
-- (weapon_dues_claws) -- which is what keeps four of them from turning a skirmish into a set-piece.
function Toll.spawnDue(combat, fallen)
    if not (combat and fallen) then return nil end
    local Combat = C()
    local x, y = Combat.openTileNear(combat, fallen.x, fallen.y)
    if not x then return nil end
    local char
    if Toll.DUE_LEVELLED then
        local level = math.max(1, math.floor(((fallen.char and fallen.char.level) or 1) * Toll.DUE_LEVELLED))
        char = require("models.growth").atLevel(Toll.DUE, level)
    else
        char = require("models.character").instantiate(Toll.DUE)
    end
    local due = Combat.addUnit(combat, char, fallen.side, x, y, { control = "ai", summoned = false })
    Combat.enterTile(combat, due, x, y)
    if not due.alive then return nil end
    due.dueTarget = Toll.killerOf(fallen)
    Combat.logEvent(combat, "action", string.format("What %s was owed climbs out of it.", name(fallen)), { fallen, due })
    return due
end

-- ---------------------------------------------------------------------------------------------- TOLL OF HOURS

-- Does a cast of `item` count as using an ability? Every working that is not a weapon's swing or a draught drunk:
-- an ability, a signature relic, a coat's or a charm's active. The Tollkeepers price what you DO, and a swing is
-- what their own collectors do.
function Toll.isAbility(item)
    if not (item and item.activeAbility) then return false end
    return item.type ~= "weapon" and item.type ~= "consumable"
end

-- `caster` used `item` within `range` of `bearer`: it owes its next move. Recorded on the body and collected as its
-- next turn opens (Toll.collect), so the cast it has just made still resolves and the price lands on the turn after.
function Toll.owe(combat, bearer, caster, item, range, foesOnly)
    if not (bearer and bearer.alive and caster and caster.alive and caster ~= bearer) then return false end
    if foesOnly and caster.side == bearer.side then return false end
    if not Toll.isAbility(item) then return false end
    if C().unitGap(caster, bearer) > (range or 4) then return false end
    if caster.tollOwed then return false end
    caster.tollOwed = true
    C().logEvent(combat, "status", string.format("%s owes %s an hour.", name(caster), name(bearer)), { bearer, caster })
    return true
end

-- `actor`'s turn just opened: if it owes, it pays -- Rooted for this turn. The Root lasts one tick, which no turn
-- outlives, so the price is exactly this turn's move and never the one after.
function Toll.collect(combat, actor)
    if not (actor and actor.alive and actor.tollOwed) then return false end
    actor.tollOwed = nil
    Status.apply(combat, actor, "status_root", { duration = 1 })
    return true
end

-- ---------------------------------------------------------------------------------------------- PASSAGE PAID

-- Is (x, y) one of `gate`'s gate tiles? Every tile edge-on to her body.
function Toll.isGateTile(gate, x, y)
    return gate ~= nil and C().cellGap(x, y, gate) == 1
end

-- `actor`'s turn opened beside the gate (or anywhere): note where it stood, so the turn's end can ask whether it
-- spent the whole turn doing nothing there.
function Toll.noteTurn(combat, actor)
    combat._tollTurn = { unit = actor, x = actor.x, y = actor.y }
end

-- `actor` used something this turn: that is not paying passage.
function Toll.noteAct(combat, actor)
    local rec = combat and combat._tollTurn
    if rec and rec.unit == actor then rec.acted = true end
end

-- Did `actor` spend this whole turn doing nothing, on the tile it opened on? No item used, no step taken, and not a
-- turn a hard control took from it -- a Stunned body standing at the gate has not paid anything.
local function idled(combat, actor)
    local rec = combat._tollTurn
    if not (rec and rec.unit == actor and not rec.acted) then return false end
    if rec.x ~= actor.x or rec.y ~= actor.y then return false end
    if combat.turn and combat.turn.unit == actor and combat.turn.moved then return false end
    return not Status.disablesReactions(actor)
end

-- `actor`'s turn just ended. A foe of the gate that idled on a gate tile is let through: it leaves the board safe
-- (Combat.dismiss -- no corpse, no wound, its conjurations go with it). When the last of its company passes, every
-- gate still standing withholds its drop: she pays only if she falls.
function Toll.passage(combat, gate, actor)
    if not (gate and gate.alive and actor and actor.alive) then return false end
    if actor.side == gate.side or actor.summoned or actor.decoyOf then return false end
    if not Toll.isGateTile(gate, actor.x, actor.y) or not idled(combat, actor) then return false end
    local side = actor.side
    C().dismiss(combat, actor, string.format("%s pays the toll and passes through the gate.", name(actor)))
    actor.passed = true
    if Toll.passedThrough(combat, side) then
        for _, u in ipairs(combat.units or {}) do
            if u.alive and T().flag(u, "passagePaid") and u.char then u.char.dropsWithheld = true end
        end
    end
    return true
end

-- HAS `side` PAID ITS WAY THROUGH? At least one body passed, and no body of the side is left standing. Read by
-- Combat.outcomeFor ahead of the wipe check, because a company that walked out has not been wiped out. Summons do
-- not count either way: a passing body takes its own with it, and a conjuration is nobody's passage.
function Toll.passedThrough(combat, side)
    local passed = false
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.side == side then
            if u.passed then passed = true
            elseif u.alive and not u.summoned then return false end
        end
    end
    return passed
end

-- ---------------------------------------------------------------------------------------------- THE PLANNER

-- Strike `tt` with the default weapon, walking first if it must; nil when it cannot be reached this turn.
local function strikeAt(combat, unit, tt, reason)
    local Combat = C()
    local weapon = Combat.defaultWeapon(unit.char)
    local ab = weapon and weapon.activeAbility
    if not ab then return nil end
    local minRange = Combat.abilityMinRange(ab)
    local nodes = { { x = unit.x, y = unit.y, steps = 0 } }
    if not Status.blocksMove(unit) then
        for _, node in ipairs(Combat.reachableList(combat, unit)) do nodes[#nodes + 1] = node end
    end
    local best
    for _, node in ipairs(nodes) do
        local range = Combat.abilityRange(combat, unit, ab, node.x, node.y) + Combat.adjacencyRangeBonus(unit.char, weapon)
        local d, cx, cy = Combat.reachFrom(unit, node.x, node.y, tt)
        if d <= range and d >= minRange and (not best or node.steps < best.steps) then
            best = { x = node.x, y = node.y, tx = cx, ty = cy, steps = node.steps }
        end
    end
    if not best then return nil end
    local plan = { item = weapon, tx = best.tx, ty = best.ty, reason = reason }
    if best.x ~= unit.x or best.y ~= unit.y then plan.move = { x = best.x, y = best.y } end
    return plan
end

-- The Due goes for its killer: strikes it if it can reach it this turn, closes on it if it cannot.
local function huntPlan(combat, unit)
    local tt = unit.dueTarget
    if not (tt and tt.alive and tt.side ~= unit.side and not C().isOffTile(tt)) then return nil end
    local plan = strikeAt(combat, unit, tt, "collecting what it was owed")
    if plan then return plan end
    if Status.blocksMove(unit) then return nil end
    local dest
    for _, node in ipairs(C().reachableList(combat, unit)) do
        local d = C().cellGap(node.x, node.y, tt)
        if not dest or d < dest.d then dest = { x = node.x, y = node.y, d = d } end
    end
    if dest and dest.d < C().cellGap(unit.x, unit.y, tt) then
        return { move = { x = dest.x, y = dest.y }, reason = "closing on its debtor" }
    end
    return nil
end

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- Is any foe of `unit` edge-on to (x, y)?
local function besideAFoe(combat, unit, x, y)
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side ~= unit.side and not C().isOffTile(u) and C().cellGap(x, y, u) == 1 then return true end
    end
    return false
end

-- THE OUTRIDER'S TURN. It rides the lane that runs through the most foes, from wherever it can reach -- and it does
-- not look behind them, because a mount at the gallop does not: a lane that ends on a wall or a body is ridden all
-- the same, and that is the ride that stops dead. It prefers a lane that would leave it standing clear of every foe.
-- With no foe to ride through, it never ends a turn beside one: it keeps a tile off the nearest foe, ready for the
-- next lane.
local function ridePlan(combat, unit, weapon)
    local Combat = C()
    local nodes = { { x = unit.x, y = unit.y, steps = 0 } }
    local canMove = not Status.blocksMove(unit) and not Status.stopsMovement(unit)
    if canMove then
        for _, node in ipairs(Combat.reachableList(combat, unit)) do nodes[#nodes + 1] = node end
    end
    local function bodyAt(x, y) return Combat.unitAt(combat, x, y) end
    local length = (weapon.activeAbility.ride and weapon.activeAbility.ride.length) or Toll.RIDE_LENGTH
    local best
    if not Status.blocksMove(unit) then
        for _, node in ipairs(nodes) do
            for _, d in ipairs(DIRS) do
                local cells = Toll.lane(combat, node.x, node.y, d[1], d[2], length, bodyAt, unit)
                local foes, friends = 0, 0
                for _, c in ipairs(cells) do
                    if c.body then
                        if c.body.side ~= unit.side then foes = foes + 1 else friends = friends + 1 end
                    end
                end
                if foes > 0 then
                    local land = Toll.exit(cells)
                    local clear = land and not besideAFoe(combat, unit, land.x, land.y)
                    local score = foes * 10 - friends * 12 + (clear and 3 or 0)
                    local cand = { x = node.x, y = node.y, tx = node.x + d[1], ty = node.y + d[2],
                        steps = node.steps or 0, score = score }
                    if score > 0 and (not best or score > best.score
                        or (score == best.score and cand.steps < best.steps)) then
                        best = cand
                    end
                end
            end
        end
    end
    if best then
        local plan = { item = weapon, tx = best.tx, ty = best.ty, reason = "ride past" }
        if best.x ~= unit.x or best.y ~= unit.y then plan.move = { x = best.x, y = best.y } end
        return plan
    end
    -- Nothing to ride through: stand off. The tile nearest the nearest foe that is beside none of them.
    local function nearestFoe(x, y)
        local nd
        for _, u in ipairs(combat.units or {}) do
            if u.alive and u.side ~= unit.side and not Combat.isOffTile(u) then
                local g = Combat.cellGap(x, y, u)
                if not nd or g < nd then nd = g end
            end
        end
        return nd or math.huge
    end
    local stand
    for _, node in ipairs(nodes) do
        if not besideAFoe(combat, unit, node.x, node.y) then
            local nd = nearestFoe(node.x, node.y)
            if not stand or nd < stand.nd or (nd == stand.nd and (node.steps or 0) < stand.steps) then
                stand = { x = node.x, y = node.y, nd = nd, steps = node.steps or 0 }
            end
        end
    end
    if stand and (stand.x ~= unit.x or stand.y ~= unit.y) then
        return { move = { x = stand.x, y = stand.y }, reason = "ride past: keeping off" }
    end
    return { wait = true, reason = "ride past: holding off" }
end

-- AI.preempt: the Due hunts its killer, the Outrider rides. A Taunt still outranks both, and a body the company
-- drives is never compelled.
function Toll.plan(combat, unit)
    if not (unit and unit.alive and unit.side ~= "party") then return nil end
    if Status.has(unit, "status_taunt") then return nil end
    if unit.dueTarget then
        local plan = huntPlan(combat, unit)
        if plan then return plan end
    end
    local weapon = C().defaultWeapon(unit.char)
    local ab = weapon and weapon.activeAbility
    if ab and ab.ride and ab.ride.planned then return ridePlan(combat, unit, weapon) end
    return nil
end

return Toll
