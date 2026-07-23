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
-- It still shoots what it is aimed at -- an arrow is an arrow -- but only for a token amount. The damage
-- is not the sale and it is not meant to be a compromise; the trap is the weapon.
return {
    name = "Deadfall Bow",
    description = "Drawn over a full turn, then driven into the ground: it arms a trap where it lands instead of loosing.",
    flavor = "The Lodge's trappers do not draw on the animal. They draw on the path.",
    sprite = "assets/items/deadfall_bow.png",
    type = "weapon",
    tags = { "longbow", "pierce", "physical", "ranged" },
    hands = 2,
    class = "hunter",
    activeAbility = {
        target = "enemy",
        range = 5,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        channel = 2,
        cost = { stat = "stamina", amount = 10 },
        -- Token, and openly so: the shaft is being planted rather than loosed.
        damage = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7 },
        effect = function(fx)
            if fx.target then fx.damage(fx.target) end
            -- Armed on the aimed CELL. A bear trap rather than a spike trap: what the Lodge sells is a
            -- body held where you wanted it, not a body hurt where it stood -- and holding is what makes
            -- the spent turn back for the rest of the party.
            fx.placeTrap(fx.tx, fx.ty, "bear_trap", { amount = 6 + 2 * fx.level })
        end,
    },
}
