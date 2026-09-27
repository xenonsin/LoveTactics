-- THE THIRST: the rules every vampire lives by (Wrath's vampires, reviewed over three rounds on 2026-09-26/27,
-- "The Vampires of Wrath"). A vampire is a TAG on top of a race and a class, like the undead tag it implies
-- (models/character.lua's `vampire`): a goblin Fledgling is still a goblin, with Blood Feud, and ALSO a vampire.
--
--   THE THIRST      every turn a vampire ends without having drawn blood from a LIVING body, +1 Thirst
--                   (status_thirst). At 3 (2 for the newly turned) it is in Bloodlust (status_bloodlust): more
--                   damage and a step more, only its bite, and it goes for the NEAREST body, either side.
--   FEEDING         drawing blood from a living body resets the Thirst and ends Bloodlust, and heals the
--                   vampire 30% of what it drew. That heal is flagged `feeding`, and Grave-Cold does not turn a
--                   feeding heal into a wound (Combat.applyHeal) -- every other heal still burns it.
--   THE BITE        a vampire's weapon strike IS the bite: it opens a vein (status_bleed, with the vampire as
--                   the wound's `opener`).
--   RUNNING FEEDS   Bleed a foe takes counts as blood drawn by whoever OPENED that wound (the status carries
--                   its opener; the tick hands it to Combat.dealFlatDamage as `opts.bledBy`).
--   SCENT OF BLOOD  +2 movement on a move toward a bleeding foe, +20% damage to a bleeding foe.
--   BLOOD BOND      while the Sire stands, no vampire on its side may enter Bloodlust -- their Thirst stops
--                   at 2 -- and when it falls, every one of them enters Bloodlust at once.
--   TITHE           each time one of the Sire's brood draws blood, the Sire heals 10% of that drink.
--   BLOOD COURIER   a Familiar's drink goes to the nearest vampire on its side, as if the vampire had bitten --
--                   or, for a Familiar the company whistled up, to the body that called it.
--
-- "Drawing blood" is read narrowly on purpose: a WEAPON strike that wounds a living body (the bite, the
-- Familiar's teeth), or a Bleed tick on a wound the drinker opened. A spell does not draw blood, so a
-- Hemomancer that only casts goes thirsty like any other. Undead have no blood, and neither does a construct,
-- an elemental or a prop (Thirst.isLiving).
--
-- Pure logic, no love.graphics. Combat, Status and Trait are required lazily, since combat.lua reaches this
-- module from inside its damage and heal funnels.
local Character = require("models.character")

local Thirst = {}

Thirst.STATUS = "status_thirst"
Thirst.BLOODLUST = "status_bloodlust"
Thirst.THRESHOLD = 3          -- Thirst at which a vampire enters Bloodlust
Thirst.NEWLY_TURNED = 2       -- ...and a Fledgling, newly turned, one sooner
Thirst.BOND_CAP = 2           -- while the Sire stands, Thirst stops here
Thirst.FEED_SHARE = 0.30      -- a drink heals this share of what was drawn
Thirst.TITHE_SHARE = 0.10     -- and the Sire this share of it
Thirst.SCENT_MOVE = 2         -- Scent of Blood: extra movement toward (or beside) a bleeding foe
Thirst.SCENT_DAMAGE = 0.20    -- ...and extra damage against one
Thirst.BLOODLUST_DAMAGE = 0.30
Thirst.BLOODLUST_MOVE = 1

local NOT_LIVING = { construct = true, elemental = true, object = true }

-- Is `unit` a vampire? The tag on its character (Character.isVampire).
function Thirst.isVampire(unit)
    return unit ~= nil and Character.isVampire(unit.char)
end

-- Does `unit` have blood to draw? Not the dead, and not a thing that was never alive.
function Thirst.isLiving(unit)
    if not (unit and unit.char) then return false end
    if Character.isUndead(unit.char) then return false end
    return not NOT_LIVING[unit.char.kind or ""]
end

-- How thirsty `unit` is (its Thirst stacks).
function Thirst.level(unit)
    return require("models.status").stacksOf(unit, Thirst.STATUS)
end

-- The Thirst at which `unit` enters Bloodlust. A blueprint declaring `newlyTurned` (the Fledglings) goes sooner.
function Thirst.threshold(unit)
    local def = unit and unit.char and Character.defs[unit.char.id]
    if def and def.newlyTurned then return Thirst.NEWLY_TURNED end
    return Thirst.THRESHOLD
end

-- The living body on `unit`'s side carrying `flag` (the Sire's `bloodBond` / `tithe`), or nil.
local function allyWithFlag(combat, unit, flag, exceptSelf)
    local Trait = require("models.trait")
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.alive and u.side == unit.side and not (exceptSelf and u == unit) and Trait.flag(u, flag) then
            return u
        end
    end
    return nil
end

-- Is `unit` held by a Sire's Blood Bond (a Sire standing on its side, itself included)?
function Thirst.bonded(combat, unit)
    return allyWithFlag(combat, unit, "bloodBond", false) ~= nil
end

-- Put `unit` into Bloodlust: +30% of its own Damage and +1 Movement, bite only, the nearest body. `duration`
-- is optional (the Signet's two turns); a vampire's lasts until it drinks.
function Thirst.enterBloodlust(combat, unit, duration)
    if not (unit and unit.alive) then return nil end
    local Combat = require("models.combat")
    local Status = require("models.status")
    if Status.has(unit, Thirst.BLOODLUST) then return Status.get(unit, Thirst.BLOODLUST) end
    local extra = math.max(1, math.floor(Combat.flatStat(unit, "damage") * Thirst.BLOODLUST_DAMAGE + 0.5))
    local st = Status.apply(combat, unit, Thirst.BLOODLUST, {
        duration = duration,
        statBonus = { damage = extra, movement = Thirst.BLOODLUST_MOVE },
    })
    Combat.logEvent(combat, "action", string.format("%s is in Bloodlust.", (unit.char and unit.char.name) or "It"), unit)
    return st
end

-- A heal that is a DRINK: Grave-Cold lets it through (Combat.applyHeal's `feeding`).
local function feedingHeal(combat, unit, amount)
    if amount <= 0 or not (unit and unit.alive) then return 0 end
    return require("models.combat").applyHeal(combat, unit, amount, { feeding = true })
end

-- `vamp` DRINKS `drink` points of blood: its Thirst resets, its Bloodlust ends, it heals 30% of the drink, and
-- the Sire it serves (if any) is tithed 10%. The one door every source of blood comes through -- the bite, a
-- Bleed tick, a Familiar's courier, the Communion, the thrall -- so none of them re-derives the rule.
function Thirst.feed(combat, vamp, drink)
    if not (combat and vamp and vamp.alive) then return 0 end
    local Status = require("models.status")
    vamp._drank = true
    if Status.has(vamp, Thirst.STATUS) then Status.remove(combat, vamp, Thirst.STATUS) end
    -- ...unless it is a Bloodlust that HOLDS (the burst Gorged's, models/gorged.lua): no drink lifts that one.
    if Status.has(vamp, Thirst.BLOODLUST) and not vamp.bloodlustHolds then Status.remove(combat, vamp, Thirst.BLOODLUST) end
    drink = math.max(0, drink or 0)
    local healed = feedingHeal(combat, vamp, math.max(1, math.floor(drink * Thirst.FEED_SHARE + 0.5)))
    local sire = allyWithFlag(combat, vamp, "tithe", true)
    if sire and drink > 0 then
        feedingHeal(combat, sire, math.max(1, math.floor(drink * Thirst.TITHE_SHARE + 0.5)))
    end
    return healed
end

-- The nearest living vampire on `unit`'s side (the Familiar's courier run), or nil.
function Thirst.nearestVampire(combat, unit)
    local Combat = require("models.combat")
    local best, bestD
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.alive and u ~= unit and u.side == unit.side and Thirst.isVampire(u) then
            local d = Combat.unitGap(unit, u)
            if not bestD or d < bestD then best, bestD = u, d end
        end
    end
    return best
end

-- `drinker` drew `amount` of blood from `victim`. Routed: a vampire feeds; a Familiar carries it (to the body
-- that whistled it up, or to the nearest vampire); anyone carrying Vitae's borrowed Thirst is slaked.
function Thirst.drink(combat, drinker, victim, amount)
    if not (drinker and victim and (amount or 0) > 0) then return end
    if not Thirst.isLiving(victim) then return end
    local Status = require("models.status")
    local Trait = require("models.trait")
    -- VITAE'S DEBT (status_borrowed_thirst): drawing blood from a living body before it runs out pays it.
    local debt = Status.get(drinker, "status_borrowed_thirst")
    if debt then
        debt.slaked = true
        Status.remove(combat, drinker, "status_borrowed_thirst")
    end
    if Thirst.isVampire(drinker) then
        Thirst.feed(combat, drinker, amount)
        return
    end
    if Trait.flag(drinker, "bloodCourier") then
        local caller = drinker.summoner
        if caller and caller.alive and caller.side == drinker.side then
            -- The company's Familiar (the Whistle): the drink heals whoever called it, by the damage.
            feedingHeal(combat, caller, amount)
            return
        end
        local vamp = Thirst.nearestVampire(combat, drinker)
        if vamp then Thirst.feed(combat, vamp, amount) end
    end
end

-- A WEAPON STRIKE landed (Combat.dealDamage, after the wound): `user` struck `target` with `item` for `dealt`.
-- A vampire's bite opens a vein, and any weapon on a living body is a drink.
function Thirst.onStrike(combat, user, target, item, dealt)
    if not (combat and user and target and item and (dealt or 0) > 0) then return end
    if item.type ~= "weapon" or user == target then return end
    local Status = require("models.status")
    if Thirst.isVampire(user) and target.alive then
        Status.apply(combat, target, "status_bleed", { applier = user })
        -- BAD BLOOD: a vampire in Bloodlust that bites a GOBLIN of its own side becomes that warband's Feud and
        -- they turn on it (models/feud.lua lets kin be the Feud only in Bloodlust). Marked here, at the bite and
        -- before the drink ends the Bloodlust -- the goblin's own Blood Feud hears the blow only once the cast is
        -- over, by which time it has.
        if target.side == user.side and Status.has(user, Thirst.BLOODLUST)
            and require("models.trait").flag(target, "bloodFeud") then
            require("models.feud").mark(combat, user, target)
        end
    end
    Thirst.drink(combat, user, target, dealt)
end

-- A BLEED TICK landed (status_bleed -> Combat.dealFlatDamage's `opts.bledBy`): whoever opened that wound drinks.
function Thirst.onBleed(combat, opener, target, dealt)
    if not (opener and opener.alive and target and target ~= opener) then return end
    Thirst.drink(combat, opener, target, dealt)
end

-- THE END OF A VAMPIRE'S TURN (trait_the_thirst's onTurnEnd). A turn it drank on passes; a dry one climbs the
-- Thirst -- to 2 at most while a Sire's bond holds -- and at the threshold, Bloodlust.
function Thirst.onTurnEnd(combat, unit)
    if not (combat and unit and unit.alive) then return end
    if unit._drank then unit._drank = nil return end
    local Status = require("models.status")
    local bonded = Thirst.bonded(combat, unit)
    local level = Thirst.level(unit)
    local cap = bonded and math.min(Thirst.BOND_CAP, Thirst.threshold(unit)) or Thirst.threshold(unit)
    if level < cap then
        Status.apply(combat, unit, Thirst.STATUS)
        level = Thirst.level(unit)
    end
    if not bonded and level >= Thirst.threshold(unit) then Thirst.enterBloodlust(combat, unit) end
end

-- THE BOND BREAKS (the Sire's trait_blood_bond onDeath): every vampire on `sire`'s side enters Bloodlust at
-- once, whatever its Thirst.
function Thirst.bondBreaks(combat, sire)
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.alive and u ~= sire and u.side == sire.side and Thirst.isVampire(u) then
            Thirst.enterBloodlust(combat, u)
        end
    end
end

-- ---------------------------------------------------------------------------------------------- scent of blood

-- Is any foe of `unit` bleeding?
local function bleedingFoes(combat, unit)
    local Status = require("models.status")
    local out = {}
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.alive and u.side ~= unit.side and Status.has(u, "status_bleed") then out[#out + 1] = u end
    end
    return out
end

-- The scent `unit` carries, or nil: "toward" (the vampire tag -- a move that closes on a bleeding foe) or
-- "beside" (Bloodhound's Scent -- a move that ends next to one). Read off the trait's `scent` field.
function Thirst.scentOf(unit)
    local t = require("models.trait").flag(unit, "scent")
    return t and t.def and t.def.scent or nil
end

-- The movement Scent of Blood adds to `unit`'s graph this turn: 2 while a foe bleeds, else 0.
function Thirst.scentMove(combat, unit)
    if not Thirst.scentOf(unit) then return 0 end
    if #bleedingFoes(combat, unit) == 0 then return 0 end
    return Thirst.SCENT_MOVE
end

-- May `unit` END a move on (x, y) using the scent's extra movement? "toward": the tile is closer to some
-- bleeding foe than where it stands; "beside": the tile is next to one.
function Thirst.scentAllows(combat, unit, x, y)
    local mode = Thirst.scentOf(unit)
    if not mode then return false end
    local Combat = require("models.combat")
    for _, foe in ipairs(bleedingFoes(combat, unit)) do
        local there = Combat.cellGap(x, y, foe)
        if mode == "beside" then
            if there == 1 then return true end
        elseif there < Combat.cellGap(unit.x, unit.y, foe) then
            return true
        end
    end
    return false
end

-- Scent of Blood's damage: +20% of the striker's own Damage against a bleeding foe (a trait's damageBonusVs).
function Thirst.scentDamage(ctx)
    if not (ctx.unit and ctx.target and ctx.hasStatus(ctx.target, "status_bleed")) then return 0 end
    local Combat = require("models.combat")
    return math.max(1, math.floor(Combat.flatStat(ctx.unit, "damage") * Thirst.SCENT_DAMAGE + 0.5))
end

-- ---------------------------------------------------------------------------------------------- the planner

-- A vampire's turn, or nil to let the ordinary planner run (AI.preempt). In Bloodlust it bites the nearest
-- body, either side; an enemy vampire at Thirst 2 beside a Blood-Ghoul drinks from the thrall instead.
function Thirst.plan(combat, unit)
    local Status = require("models.status")
    if Status.has(unit, Thirst.BLOODLUST) then
        return require("models.rampage").hitNearest(combat, unit, "bloodlust")
            or { wait = true, reason = "bloodlust, nothing near" }
    end
    if unit.side == "party" or not Thirst.isVampire(unit) then return nil end
    if Thirst.level(unit) < 2 then return nil end
    local Combat = require("models.combat")
    local Trait = require("models.trait")
    local feed
    for _, item in ipairs(Character.eachItem(unit.char)) do
        if item.id == "ability_feed" then feed = item break end
    end
    if not feed or Combat.itemBlockReason(unit, feed) then return nil end
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u ~= unit and u.side == unit.side and Trait.flag(u, "thrall")
            and Combat.unitGap(unit, u) == 1 then
            return { item = feed, tx = u.x, ty = u.y, reason = "feeding" }
        end
    end
    return nil
end

return Thirst
