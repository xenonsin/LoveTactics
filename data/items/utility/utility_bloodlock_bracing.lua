-- Bloodlock Bracing: the Colosseum's trade of blood for a body that will not give. A passive charm that
-- LOCKS a share of the bearer's health away for the whole battle (`healthReserve.percent`, taken through
-- the real reservation machinery in Combat.applyReservations) and pays for it in armor -- flat Defense
-- AND Magic Defense, folded from `bonus` at setup like any other worn plate. The name is the trick
-- itself: blood held back under a brace, a body made smaller and harder by the life it refuses to spend.
--
-- WHY A RESERVATION AND NOT A SMALLER MAX. A negative `maxBonus.health` would only lower the ceiling a
-- heal can climb to; the current health above it would sit there untouched until spent and then never
-- come back -- a soft cap you discover the edge of, not a cost you pay up front. A reservation is honest
-- the other way round: it spends the health on the spot (Combat.reserve) and drops the ceiling by the
-- same amount, so the brace costs you that life the instant the bell rings and the pool can never refill
-- into it. That is the promise the tooltip makes -- "locked away for the battle; it cannot be healed
-- back" -- and it is the tested behaviour reservation_spec already pins for a summon's held mana.
--
-- WHY A SHARE OF MAX AND NOT A FLAT SLAB. A percentage (Combat.healthReserveAmount reads it off max, the
-- same way an ability's reserve reads its pool) keeps the toll proportionate across every body that can
-- carry the charm: a fat pit-fighter and a slight duelist each give up the same FRACTION of themselves,
-- so the trade never quietly turns free on a big health bar or ruinous on a small one.
--
-- WHY THE BARBARIAN'S. The barbarian subclass (data/disciplines/barbarian.lua) prices power in blood --
-- Rage: damage that rises as HP falls, strikes that cost life to land harder. This is that same currency
-- turned inside out: where the rest of the discipline spends blood for a heavier blow, this spends it for
-- a wall -- broad Defense AND Magic Defense, the one thing wrath's own shelf never sold, bought with the
-- only resource the Colosseum has ever priced fights in. A deeper cut of the fighter shelf, sold only once
-- the barbarian gate is cleared, so it reads as a berserker's discipline rather than a starter charm.
--
-- THE FORGE STORY. The armor scales with the level; the reserve does NOT -- it is a flat 20% at every
-- level. Forging buys a deeper brace for the same fraction of blood -- you never pay more to stand behind
-- a better wall -- which keeps the item's promise a single readable sentence at every level and keeps the
-- blacksmith's growth sheet from charting a rising cost as though it were a gain.
--
-- NEVER LETHAL. Combat.applyReservations reserves only down to the bearer's last point of life, so a
-- fighter who walks in already wounded locks away only what it can spare -- it can cost you your buffer,
-- never your fight.
local Curve = require("models.curve")

return {
    name = "Bloodlock Bracing",
    description = "Reserves health to raise your Defense and Magic Defense.",
    flavor = "Pit-fighters learn to fight half-drowned in their own held blood. The life you keep in is the wall the crowd never sees.",
    sprite = "assets/items/bloodlock_bracing.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    discipline = "barbarian", -- deeper cut of the shelf: buyable only once the barbarian gate is cleared
    price = 400,
    unlockQuests = 9,
    -- The armor the locked blood buys, forged deeper level by level. Defense and Magic Defense move
    -- together: the brace is whole-body, not a shield turned to one school.
    bonus = {
        defense = Curve.ramp(3, 13), -- levels 0..10
        magicDefense = Curve.ramp(3, 13),
    },
    -- The cost: a fixed share of MAX health locked away for the fight (Combat.applyReservations, resolved
    -- by Combat.healthReserveAmount). A flat fraction, not level-scaled -- the forge buys more brace,
    -- never a heavier toll.
    healthReserve = { percent = 0.20 },
}
