-- CLIMBING FLAME: a burning foe struck from a distance is dragged a tile toward the bearer.
--
-- THE FIREDRAW'S RULE, HANDED OVER, AND IT IS THE HALF THAT IS ACTUALLY ABOUT THE COMBINATION. The
-- elite's whole sentence is that fire gives wind something to pull ON: its Chimney-Draw hauls a burning
-- body the length of the room and a cold one a single stumbling tile
-- (data/items/weapon/weapon_chimney_draw.lua). This is that sentence at a player's scale -- your fire
-- is the handhold, and what it holds is whatever you set alight.
--
-- THE RIFT SELLS YOU THE TRICK, which is the ordering the Barrow Lord's Marrowlight argues and the
-- Updraught repeats: a rule like this is a strange thing to be handed cold at a counter and an ordinary
-- thing to be handed by the corpse of the thing that spent a fight doing it to you.
--
-- A PULL RATHER THAN A SHOVE, AND THAT IS WHAT MAKES IT AUTHORABLE AT ALL. The harpy's own header
-- records the objection: "a pull handed to the player is already four abilities deep (Pull, Collapse,
-- Gaff Line, Indrawn Breath) while nothing in the game puts a shove on an ordinary swing", which is why
-- the flock sells the shove. That objection is about a CAST. This is a rider on a blow you were going
-- to throw anyway, gated on a condition you had to spend something to create -- and the direction is
-- the reason the gate can be this loose. A shove-on-every-arrow is a free disengage and strictly good,
-- which is precisely why trait_stooping_blow is melee-only; a PULL-on-every-arrow brings the thing you
-- are shooting one tile nearer, and a player who does not want that simply stops shooting burning
-- things. It is only ever an advantage on purpose.
--
-- WHICH IS WHY IT SHELVES AT THE BOMBARDIER. "Throws bombs at range. Each one leaves a hazard on the
-- ground where it lands" (data/classes/bombardier.lua) -- a shelf whose whole stock sets fires and
-- covers ground in things you would like the enemy to walk over. This is the piece that makes them
-- walk over it. Combat.pull springs every trap and hazard on the way in, one tile at a time, so the
-- drag itself is half the damage against a board that shelf has prepared. That is a synergy the player
-- assembles out of two houses rather than a rung handed out ([[a-pair-is-a-synergy-not-a-tier]]).
--
-- GATED ON GAP > 1, WHICH IS NOT A CATEGORY BUT A REFUSAL TO PAY TWICE. A drag aimed at a foe already
-- standing beside you has nowhere to put it: the step lands on the bearer's own tile, Combat.knockback
-- finds the shift blocked and bills impact damage instead -- so without this line a melee build would
-- get free collision damage on every swing against anything burning, which is a damage rider wearing a
-- control rider's name. At reach it moves a body; in melee it would only ever have been a number.
-- BOTH REQUIRES ARE LAZY, INSIDE THE HOOK, and that is load order rather than style. models/trait.lua
-- scans this folder AT LOAD (registry.lua), and models/combat.lua requires models/trait.lua at its own
-- top -- so a `require("models.combat")` in this chunk's main body closes the loop and the whole game
-- fails to boot with "loop or previous error loading module". It shipped that way for one sitting and
-- cost three test runs that looked like hangs rather than errors. Every trait that reaches for a model
-- does it from inside its hook (trait_borrowed_blood, trait_anvil_face); this is that rule, written
-- down where it was broken.
return {
    name = "Climbing Flame",
    description = "A burning foe you hit at range is dragged a tile toward you.",
    onCast = function(ctx)
        -- A BLOW THAT DREW NO BLOOD DRAGS NOBODY. onCast fires on a thrown swing as readily as on a
        -- landed one, so without this the drag would be a rider that cannot miss riding a blow that
        -- can -- the bug the whole circle was rebuilt out of once already (docs/accuracy.md).
        if (ctx.damageDealt or 0) <= 0 then return end
        local Combat, Status = require("models.combat"), require("models.status")
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not target or not target.alive or target.side == ctx.unit.side then return end
        if not Status.has(target, "status_burn") then return end
        if ctx.gap(target) <= 1 then return end -- see the header: in melee this is damage, not control

        -- ONE TILE, TOWARD. ctx.knockback drives a body straight AWAY from its source unless handed a
        -- destination, and `opts.dest` makes it walk toward that tile instead for as far as the tile is
        -- (Combat.knockback). So the destination is computed one step along the dominant axis rather
        -- than handed the bearer's own tile, which would haul the target the whole distance and end in
        -- a collision. signDominant's rule, restated here because the primitive does not export it.
        local dx, dy = ctx.unit.x - target.x, ctx.unit.y - target.y
        local sx, sy = 0, 0
        if math.abs(dx) >= math.abs(dy) then
            sx = (dx > 0 and 1) or (dx < 0 and -1) or 0
        else
            sy = (dy > 0 and 1) or (dy < 0 and -1) or 0
        end
        if sx == 0 and sy == 0 then return end
        Combat.knockback(ctx.combat, ctx.unit, target, 1,
            { dest = { x = target.x + sx, y = target.y + sy } })
    end,
}
