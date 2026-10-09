-- RACE ITEMS: the seams the sixteen race-and-class items reach into ("The Rift's Adventurers", slice D,
-- approved 2026-10-09). The items themselves are data/items/utility/<id>.lua, listed by pairing in
-- models/adventurers.lua's RACE_ITEMS, and each is gated to its race by Character.canCarry.
--
-- WHY A MODULE OF ITS OWN. Most of the sixteen rules are a clause on something another file already
-- does -- a steal, a shove, a bowshot's reach, a stack spent, a guard taking a blow. A rule like that
-- cannot be a trait hook, because the action it bends is not an event a trait hears; it is a question
-- the engine asks at its own seam (Trait.flag's whole argument). So each rule's trait carries only a
-- FLAG, the engine asks this file at the one seam the rule bends, and the arithmetic lives here once
-- rather than spread across combat.lua's call sites. Every call site is one line in a block labelled
-- "THE RIFT'S ADVENTURERS, SLICE D", so the seams can be found by searching for that label.
--
-- PURE QUERIES, except where a name says otherwise (`spareUse`, `tookBlow`): the forecast, the planner
-- and the tooltip ask the reach, the hit chance and the anchor on every hover, so those must bank and
-- spend nothing. Combat, Status, Trait and Feud are pulled lazily, so this sits in no require cycle.

local RaceItems = {}

local function Trait() return require("models.trait") end
local function Status() return require("models.status") end
local function Combat() return require("models.combat") end

local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do
        if t == want then return true end
    end
    return false
end

-- --------------------------------------------------------------- Mountain's Root (dwarf, bulwark)

-- Is `unit` held by a Mountain's Root: its own, or that of an ally standing beside it? Read by
-- Status.blocksForcedMove (no shove, drag, throw or charge moves it) and by Combat.steal and Combat.strip
-- (nothing is taken out of its grid). Through Trait.flag, so a Sundered bearer holds nobody.
function RaceItems.rooted(unit)
    if not unit or unit.alive == false then return false end
    if Trait().flag(unit, "mountainsRoot") then return true end
    local combat = unit.combat
    if not (combat and combat.units) then return false end
    for _, u in ipairs(combat.units) do
        if u ~= unit and u.alive and not u.incapacitated and u.side == unit.side
            and Trait().flag(u, "mountainsRoot") and Combat().unitGap(u, unit) == 1 then
            return true
        end
    end
    return false
end

-- ----------------------------------------------------------------- Hoardkeeper (dwarf, mammonite)

-- Does `unit` keep what it has banked? A Skimmer's Cut lifts nothing off it (trait_skimmers_cut). The one
-- path in the game that takes gold off a body mid-fight, so it is the whole of "cannot be stolen".
function RaceItems.keepsHoard(unit)
    return unit ~= nil and Trait().flag(unit, "keepsHoard") ~= nil
end

-- What a coin heap of `gold` banks for `unit` when it picks it up: twice over for a Hoardkeeper.
function RaceItems.heapTake(unit, gold)
    if RaceItems.keepsHoard(unit) then return gold * 2 end
    return gold
end

-- --------------------------------------------------------------------- Flawless Shot (elf, hunter)

-- Is `item` a bow? The bow family contains the longbow (Combat.FAMILY_CONTAINS).
local function isBow(item)
    return item ~= nil and item.type == "weapon" and (hasTag(item.tags, "bow") or hasTag(item.tags, "longbow"))
end

local function flawless(unit)
    return unit ~= nil and Trait().flag(unit, "flawlessShot") ~= nil
        and Status().has(unit, "status_unblemished")
end

-- Does this shot skip the dice? A bow shot from an Unblemished bearer of Flawless Shot. Read by
-- Combat.rollsToHit, so the forecast, the planner and the swing say 100 together.
function RaceItems.sureShot(user, item)
    return isBow(item) and flawless(user)
end

-- The extra reach `ab` has for `unit`: 1 when `ab` is a bow's shot and the bearer is Unblemished. Read by
-- Combat.abilityRange, which is handed the ability alone, so the bow is found by the ability it carries.
function RaceItems.rangeBonus(unit, ab)
    if not (ab and unit and unit.char and flawless(unit)) then return 0 end
    for _, item in ipairs(require("models.character").eachItem(unit.char)) do
        if item.activeAbility == ab then return isBow(item) and 1 or 0 end
    end
    return 0
end

-- ---------------------------------------------------------------------- Perfect Form (elf, duelist)

-- How far one more blow on the same foe moves the duelist's stance: the same-target streak every Tempo
-- pool and the Long Bout read (Combat.dealDamage), and En Garde's own stack. 2 for an Unblemished bearer
-- of Perfect Form, 1 for everyone else.
function RaceItems.streakStep(unit)
    if unit and Trait().flag(unit, "perfectForm") and Status().has(unit, "status_unblemished") then return 2 end
    return 1
end

-- ------------------------------------------------------------------- Blood Tally (orc, barbarian)

-- How much of `unit`'s health counts as spent for a Fury that scales on it (Desperate Strike, The Red
-- Account): what is really gone, plus a tenth for each Proven a Blood Tally bearer carries. 0..1.
RaceItems.TALLY_PER_PROVEN = 0.1

function RaceItems.healthSpent(unit)
    local hp = unit and unit.char and unit.char.stats and unit.char.stats.health
    local max = hp and hp.max or 0
    local spent = max > 0 and math.max(0, 1 - ((hp.current or 0) / max)) or 0
    if Trait().flag(unit, "bloodTally") then
        spent = spent + RaceItems.TALLY_PER_PROVEN * Status().stacksOf(unit, "status_proven")
    end
    return math.min(1, spent)
end

-- --------------------------------------------------------------------- Grudge Purse (goblin, thief)

-- THE THIEF'S STEALS: the four pieces on the thief's shelf that take something off a body -- an item
-- (Pickpocket), its Damage (Sap), its gold (Shakedown), or one of its abilities (the Flaying Knife).
-- A closed, named set rather than a tag, because no tag says "takes" (`guile` is the rogue's word for a
-- conditional multiplier, and Pickpocket's `thievery` is on Pickpocket alone).
RaceItems.STEALS = {
    ability_pickpocket = true, ability_sap = true, ability_shakedown = true, weapon_flaying_knife = true,
}

-- Does this steal skip the dice? A Grudge Purse bearer's steal from its side's Feud. Read by
-- Combat.rollsToHit.
function RaceItems.sureSteal(user, target, item)
    if not (item and RaceItems.STEALS[item.id]) then return false end
    if not (user and Trait().flag(user, "grudgePurse")) then return false end
    return require("models.feud").isFeudOf(user, target)
end

-- ------------------------------------------------------------------ Never Alone (goblin, saboteur)

-- Is one of `unit`'s own hidden charges (a trap it set) within `radius` of it? Read by trait_mob_courage:
-- a Never Alone bearer counts them as goblins, and does not Cower beside one.
function RaceItems.chargeNear(combat, unit, radius)
    if not (combat and unit and Trait().flag(unit, "neverAlone")) then return false end
    for _, t in ipairs(combat.traps or {}) do
        if t.alive and t.placer == unit and Combat().cellGap(t.x, t.y, unit) <= radius then return true end
    end
    return false
end

-- ------------------------------------------------------------------- Many Hands (kobold, trapper)

-- How many of `unit`'s own traps lie beside `target`, which a Many Hands bearer counts as kobolds for
-- Underfoot's Pack (trait_pack). 0 for everyone else.
function RaceItems.trapsBeside(combat, unit, target)
    if not (combat and unit and target and Trait().flag(unit, "manyHands")) then return 0 end
    local n = 0
    for _, t in ipairs(combat.traps or {}) do
        if t.alive and t.placer == unit and Combat().cellGap(t.x, t.y, target) == 1 then n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------- Dragon-Kin (kobold, beastmaster)

-- Is `unit` a bonded beast its summoner's Dragon-Kin makes a dragon? A creature the bearer summoned and
-- that still stands -- never a planted object (a banner, a totem). Read by Devotion.isDragon, so the
-- Dragon's Eye a kobold fights under reads it like an egg.
function RaceItems.beastIsDragon(unit)
    local owner = unit and unit.summoned and unit.summoner
    if not (owner and owner.alive) then return false end
    if unit.char and unit.char.race == "object" then return false end
    return Trait().flag(owner, "beastIsDragon") ~= nil
end

-- ---------------------------------------------------------------- Well Stocked (human, alchemist)

-- Does this use of `item` leave its stack alone? The first use of each consumable a Well Stocked bearer
-- makes in a fight is free, so every one of them has one more use. MUTATING (it marks the use spent), so
-- it is called only where a stack is really spent: Combat.useItem, a channel's start, Combat.quaff.
function RaceItems.spareUse(unit, item)
    if not (unit and item and item.type == "consumable") then return false end
    if not Trait().flag(unit, "wellStocked") then return false end
    unit.wellStockedSpared = unit.wellStockedSpared or {}
    if unit.wellStockedSpared[item] then return false end
    unit.wellStockedSpared[item] = true
    return true
end

-- -------------------------------------------------------------------- Sworn Shield (human, knight)

-- `guardian` took a blow aimed at `ward` (Combat.tryRedirect): a Sworn Shield bearer Blesses the ally.
function RaceItems.tookBlow(combat, guardian, ward)
    if not (combat and guardian and ward and ward.alive) then return end
    if not Trait().flag(guardian, "swornShield") then return end
    Status().apply(combat, ward, "status_blessing", { applier = guardian })
end

return RaceItems
