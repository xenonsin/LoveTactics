-- Savior's Watch: the Crusader hits harder and moves further while somebody near it is hurt. Damage
-- and movement for each wounded ally within three tiles, capped at three of them.
--
-- A LIVE PASSIVE (Trait.liveBonus, folded into Combat.flatStat): recomputed on every read, not banked
-- when something happened. That matters more here than anywhere else in the folder, because the thing
-- it measures goes DOWN as well as up -- heal the ally and the bonus should go with it. A banked
-- version would pay a Crusader forever for a wound that closed two turns ago, which is not zeal, it is
-- an exploit with a story attached.
--
-- MOVEMENT IS THE POINT, not the damage. The damage is what makes the charm worth a cell; the square
-- is what makes it a RESCUE. A Crusader three tiles from a dying priest cannot reach them, and this is
-- the item that says: yes you can, because they are dying. It is the only movement in the game that
-- arrives exactly when the reason to move does.
--
-- Capped at 3 because it must not scale with the size of a disaster. Uncapped, the correct play would
-- be to let the whole company get hurt -- a party wipe would be this Crusader's best turn of the fight,
-- which inverts what the item is for. Three is the whole party bar the bearer at MAX_FIELD 4, so the
-- cap is reached exactly when everyone still standing needs help.
--
-- Radius 3 rather than 1: this is a charm about crossing ground to somebody, so it has to be able to
-- see across the ground it is about to cross.
return {
    name = "Savior's Watch",
    description = "Increase damage by 2 and movement by 1 per wounded ally within 3 tiles, up to 3.",
    live = function(ctx)
        local n = ctx.countWounded(3, "ally")
        if n == 0 then return nil end
        if n > 3 then n = 3 end
        return { damage = 2 * n, movement = 1 * n }
    end,
}
