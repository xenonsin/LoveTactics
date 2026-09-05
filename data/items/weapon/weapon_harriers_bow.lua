-- Harrier's Bow: the Skirmisher's own weapon (fighter x hunter), and the only one of the 21 multiclasses
-- that had none. The shot does not close your movement -- fire, then ride.
--
-- Built on S2's free action (`free = true`): the cast bills no initiative and leaves the turn open, so a
-- skirmisher who has not yet moved can shoot and THEN go. That is the hit-and-run fantasy stated exactly,
-- and it is the thing every earlier draft of this shelf circled without landing on -- Fall Back, Broken
-- Ground and Snapshot were all denied, and all three were versions of "a way to move or shoot for free".
-- This is the version where the freedom is the WEAPON, so it costs a grid cell and a family slot.
--
-- The freedom is the MOVE, not a second attack. `soleAction = true`: the shot is still the turn's action,
-- so nothing may be used after it -- only the move it left open. Without this the free shot stacked ON TOP
-- of a full normal turn (fire, then swing a second weapon too), which is two attacks a turn, not the
-- hit-and-run the header promises. "Fire, then ride" means exactly that -- fire, then only ride.
--
-- The family contract holds: the bow archetype's business is distance and line of sight
-- (docs/weapons.md), and this keeps both. What it trades for the free shot is weight -- the damage curve
-- sits below the plain iron bow's, because a shot you did not spend your turn on should not also be your
-- best one.
--
-- Bounded by Combat.FREE_ACTIONS_PER_TURN, so it is one free shot per turn and not a bow that fires
-- until the stamina runs out. The grid greys it out afterwards with a reason
-- (Combat.itemBlockReason), rather than leaving the player to discover the limit by clicking.
local Curve = require("models.curve")

return {
    name = "Harrier's Bow",
    description = "Fires without ending your turn, leaving your move to spend.",
    flavor = "Loosed at the gallop, from the wrong shoulder, going away. It is not a good shot. It is an unanswerable one.",
    sprite = "assets/items/weapon_harriers_bow.png",
    type = "weapon",
    tags = { "bow", "pierce", "physical", "ranged" },
    class = "skirmisher",
    unlockQuests = 8,
    dropTier = 7,
    hands = 2, -- the family contract: every bow is two-handed (docs/weapons.md)
    activeAbility = {
        target = "enemy",
        range = 4,
        minRange = 2, -- the family contract: a bow has no point-blank shot (docs/weapons.md)
        requiresSight = true,
        speed = 3,
        free = true, -- S2: bills no initiative and leaves the turn open (docs/classes.md)
        soleAction = true, -- ...but still the turn's action: only the move stays open, never a second attack
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(15, 25), -- under the iron bow: the freedom is the price
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
