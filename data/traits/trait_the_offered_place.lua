-- THE OFFERED PLACE: the succubus's kiss with the player's name on it. Every melee blow the bearer
-- lands trades tiles with what it hit.
--
-- THE RIFT SELLS YOU THE TRICK, which is the ordering the Barrow Lord's Marrowlight argues in full: a
-- rule that puts you on the far side of whatever you just swung at is a strange thing to be handed cold
-- at a counter, and an ordinary thing to be handed by the corpse of the body that spent a fight doing
-- it to you (data/items/weapon/weapon_parting_kiss.lua).
--
-- IT IS THE ONLY WAY THROUGH A LINE IN THE GAME. Swap is sold twice already and both are CASTS -- the
-- rogue's Swap (reach 3, a whole turn's action) and the Ninja's Shadow Trade (with a clone you had to
-- plant first). Nothing puts the trade on an ordinary swing, and a swing is what changes what this is
-- FOR: you do not spend a turn repositioning, you hit the body holding the doorway and finish the blow
-- standing behind it. A shield wall stops being a wall for exactly one body, and the body is you.
--
-- MELEE ONLY, AND THAT IS THE PRICE RATHER THAN A CATEGORY -- the same argument trait_stooping_blow
-- makes one shelf over. On a bow this would be a free blink to wherever you last shot, strictly good
-- and never once a decision. On a blade it is a genuine trade: you are now standing where the enemy
-- was, which is deeper into its line than where you started, with its friends around you and yours
-- behind it. Half the time that is the whole point and half the time it is a mistake, and which one it
-- is is decided by the board rather than by the item.
--
-- NO COOLDOWN, and it is self-limiting in the same way the Updraught is: every use moves you somewhere
-- you did not plan to be, so the more it fires the less the swing after it is worth. A pace on top would
-- only make the player guess which of their blows traded.
--
-- A BLOW THAT DREW NO BLOOD TRADES NOTHING. onCast fires on a thrown swing as readily as a landed one,
-- so without the gate the trade would be a rider that cannot miss riding a blow that can -- the bug
-- weapon_petal_touch's charm was authored out of (docs/accuracy.md).
--
-- ONE SHADOWING TO KNOW ABOUT: inside onCast, `ctx.item` is the item that was just CAST, not the item
-- this trait came off (models/trait.lua says so at the dispatcher). That is what this hook wants, and it
-- is written down because the two readings are indistinguishable at a glance and only one is right.
--
-- Combat.swapUnits springs whatever waits on BOTH tiles and refuses a trade it cannot seat two bodies
-- in. All of that belongs to the primitive and is deliberately not restated here.
return {
    name = "The Offered Place",
    description = "Your melee blows trade places with what they hit.",
    onCast = function(ctx)
        if (ctx.damageDealt or 0) <= 0 then return end
        local cast = ctx.item -- the weapon that just swung: see the shadowing note above
        if not (cast and cast.activeAbility) then return end
        local melee = false
        for _, tag in ipairs(cast.tags or {}) do
            if tag == "melee" then melee = true break end
        end
        if not melee then return end
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not target or not target.alive or target.side == ctx.unit.side then return end
        ctx.swap(target)
    end,
}
