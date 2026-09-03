-- A longbow, so it is drawn before it looses and reaches five tiles (docs/weapons.md). Its extra is that
-- the draw does not end in an arrow at all: the shaft is driven into the ground at the aimed tile and
-- becomes a snare (a bear trap), armed and waiting for whatever walks over it.
--
-- Quest-only: `class` with no `price`.
--
-- The Lodge's actual trade, and the only weapon in the game that spends a turn on a tile the enemy has
-- not reached yet. Every other thing here resolves against a body: the target is somewhere, and the
-- question is how much of it you can remove. This resolves against a PREDICTION -- you are not shooting
-- the enemy, you are shooting where the enemy is going to be, and if you read it wrong the turn is simply
-- gone.
--
-- Which is why the trap is worth so much more than the arrow would have been. A hunter who calls the
-- approach correctly gets a body held in place five tiles from their own line, on a square nobody had to
-- walk to, and the whole party gets a free turn on it.
--
-- It still shoots what it is aimed at, and it shoots for a longbow's full weight -- an arrow is an arrow.
-- That is a REVISION, and the reasoning it replaces is worth keeping: this weapon used to deal a token 2,
-- on the argument that "the damage is not the sale; the trap is the weapon." The argument was sound and
-- the number was still wrong, for a reason no amount of prose could fix -- the trap was flat and the arrow
-- was not, so "token" quietly became "nothing" by the middle of the campaign while the arrow kept pace.
--
-- Both halves are now the same quantity: a longbow's blow, either loosed into a body or laid in the dirt
-- to be collected later. What the hunter chooses between is not damage-versus-utility but WHEN and WHERE,
-- which is the choice the header above spends twenty lines describing.
--
-- It aims a TILE (`target = "tile"`, `allowOccupied`) and not a body, which is the whole point and was
-- once the whole bug: as an `enemy`-target ability it could only be pointed at somebody who was already
-- standing there, so the one weapon whose sale is shooting empty ground could never be aimed at any.
-- Occupied cells stay legal because the shot must be allowed to fall short of the read -- the foe walks
-- onto the square this turn instead of next -- and when it does, the shaft goes through the body rather
-- than into the dirt behind it: the same hold, delivered at once (status_root) instead of laid and
-- waited on. No trap is left on that tile. What the hunter bought was the body held, and a trap armed
-- under someone already caught would be the same purchase billed twice.
--
-- WHOEVER is standing there, as with data/items/weapon/weapon_hailfall_longbow.lua: a shaft driven into
-- the ground does not check the colour of the boots above it, and the Lodge's shelf does not pretend
-- otherwise. Loose it onto your own line and you have rooted your own.
local Curve = require("models.curve")

return {
    name = "Deadfall Bow",
    description = "Channeled: arms a trap where it lands, or Roots whoever is already standing there.",
    flavor = "The Lodge's trappers do not draw on the animal. They draw on the path.",
    sprite = "assets/items/deadfall_bow.png",
    type = "weapon",
    tags = { "longbow", "pierce", "physical", "ranged" },
    hands = 2,
    class = "hunter",
    dropTier = 5,
    activeAbility = {
        target = "tile",       -- the path, not the animal: the aim is a square the foe has not reached
        allowOccupied = true,  -- and a square they may already have reached (see the note above)
        range = 5,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        windup = 2,
        cost = { stat = "stamina", amount = 10 },
        -- Its slot's number (Balance.slotTarget), which is the longbow family's base exactly -- the shot
        -- is a real shot now. It used to be a token 2, and the header above still argues for that; see
        -- the note on the trap below for why the two halves had to be repriced together.
        damage = Curve.ramp(10, 20),
        effect = function(fx)
            -- Somebody is standing on the read: the shaft pins them instead of the ground. Root delivered
            -- now, and nothing left behind -- the trap would have no one left to catch.
            if fx.target then
                fx.damage(fx.target, { inflicts = "status_root" })
                return
            end
            -- Otherwise it is armed on the aimed CELL. A bear trap rather than a spike trap: what the
            -- Lodge sells is a body held where you wanted it, not a body hurt where it stood -- and
            -- holding is what makes the spent turn back for the rest of the party.
            --
            -- THE TRAP CARRIES THE ARCHER'S OWN DRAW, and that is a fix rather than a flourish. A trap's
            -- payload runs through Combat.dealFlatDamage, which subtracts armour but adds NO attack stat
            -- -- so an authored figure is the whole blow, forever. The arrow above rides the archer's
            -- Damage, which grows every level. Author them as two constants and they are two different
            -- quantities that drift apart for the whole campaign: the old flat 6 landed ONE point on the
            -- boar of the quest that grants this bow, against an arrow's fifteen, so the branch this
            -- weapon is built around was the worse play from the moment it was handed over.
            --
            -- So the trap is priced as the same blow, delivered later: the ability's own magnitude plus
            -- the archer's Damage, banked at the moment the shaft goes into the ground. Reading the stat
            -- at PLACEMENT rather than at trigger is deliberate -- the hunter who set it is the one who
            -- drew it, and a trap that got stronger because somebody levelled up three fights later
            -- would be paying the wrong person.
            --
            -- fx.level is not added on top: the magnitude already forges through the ramp above, and
            -- adding the level again would forge the same idea twice.
            local stats = fx.user and fx.user.char and fx.user.char.stats
            fx.placeTrap(fx.tx, fx.ty, "bear_trap",
                { amount = (fx.amount or 0) + ((stats and stats.damage) or 0) })
        end,
    },
}
