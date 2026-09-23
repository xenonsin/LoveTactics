-- STOOPING BLOW: the harpy's gust with the player's name on it. Every melee blow the bearer lands
-- drives what it hit back a tile.
--
-- THE RIFT SELLS YOU THE TRICK, which is the whole reason this item exists and the ordering the Barrow
-- Lord's Marrowlight already argues: a rule that makes your own swings shove is a strange thing to be
-- handed cold, and an ordinary thing to be handed by the corpse of a flock that spent a fight doing it
-- to you (data/items/weapon/weapon_stooping_gust.lua).
--
-- MELEE ONLY, AND THAT IS THE PRICE RATHER THAN A CATEGORY. On a bow this would be a free disengage on
-- every arrow, strictly good and never once a decision. On a blade it is a genuine trade: the foe you
-- just hit is now a tile further away, so you cannot follow up, you have given up the lock, and in a
-- corridor you may have pushed it somewhere you did not want it. **The bearer's own reach is what pays
-- for the control** -- exactly the argument the harpy's two weapons have with each other.
--
-- WHICH IS WHY IT SHELVES AT THE SKIRMISHER. "Strikes and moves on -- attacking frees a move
-- afterwards, so you never end a turn standing where you swung" (data/classes/skirmisher.lua). A body
-- that was going to leave anyway does not care that its target left instead; every other build pays
-- full price. That is a synergy the player assembles rather than a rung the item hands out
-- ([[a-pair-is-a-synergy-not-a-tier]] is the shape), and it is the most interesting thing this does.
--
-- NO COOLDOWN, deliberately, where trait_executioners_eye beside it carries one. The Eye converts hard
-- control into a kill window and would be a lock at every swing; this converts a hit into a foot of
-- ground and is self-limiting in a way a cooldown could only blur -- the more often it fires, the
-- further away the thing you are trying to kill is.
--
-- IT DEALS NOTHING ITSELF. The wall, the fire, the threshold and the next body in the rank do the
-- talking, exactly as a mace's shove does (Combat.knockback bills the impact of a shove it could not
-- finish). Nothing here restates any of that.
--
-- ONE SHADOWING TO KNOW ABOUT: inside onCast, `ctx.item` is the item that was just CAST, not the item
-- this trait came off -- an event field of that name shadows the granter (models/trait.lua says so at
-- the dispatcher). That is what this hook wants, and it is written down because the two readings are
-- indistinguishable at a glance and only one of them is right.
return {
    name = "Stooping Blow",
    description = "Your melee blows drive what they hit back a tile.",
    shoves = 1,
    onCast = function(ctx)
        -- A BLOW THAT DREW NO BLOOD MOVES NOBODY. onCast fires on a thrown swing as readily as on a
        -- landed one, so without this the shove would be a rider that cannot miss riding a blow that
        -- can -- the bug weapon_petal_touch's charm was authored out of (docs/accuracy.md).
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
        ctx.knockback(target, ctx.def.shoves or 1)
    end,
}
