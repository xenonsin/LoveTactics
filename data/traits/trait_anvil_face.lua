-- THE ANVIL'S FACE: hardens as it is struck, and hardens faster the angrier its bearer already is.
--
-- TWO CLAUSES, AND THE SECOND IS THE WHOLE REASON THE PIECE EXISTS (data/items/utility/utility_anvils_face.lua).
--
--   baseline   every blow taken is worth `perBlow` armour, up to `cap`. A patient plate. It works on
--              anybody, in any fight, with nothing else equipped.
--   synergy    if the bearer is carrying Rising Wrath -- which only the Mail of the Unappeased applies
--              (data/traits/trait_wrath_rising.lua) -- each blow is worth a share of the rage on top,
--              uncapped, because the rage it is reading is uncapped.
--
-- WHY THAT PAIR IS THE POINT. The Mail is an engine with no brake: it buys damage with the health you
-- are missing, so it pays best exactly when the next hit kills you. Ira could afford that. A four-body
-- company cannot. This reads the same number the Mail is generating and spends it on staying upright, so
-- the build stops being "win before the rage matters" and becomes a fight you are allowed to be in.
--
-- The baseline is NOT a token. Without the Mail this is still the answer to a swarm -- a body that gets
-- harder to chip the longer it is being chipped -- which is what makes it worth carrying out of the
-- Anvil's floor before you have ever seen Ira.
return {
    name = "Anvil's Face",
    description = "Hardens with every blow it takes, and faster while Rising Wrath is on it.",
    perBlow = 1,  -- armour a bare blow is worth
    cap = 6,      -- ...and how far that alone will carry it
    share = 4,    -- a point of armour per this many points of Rising Wrath
    onDamaged = function(ctx)
        local Status = require("models.status")
        local base = ctx.trait.plain or 0
        if base < ctx.def.cap then
            base = base + ctx.def.perBlow
            ctx.trait.plain = base
        end

        -- The rage term, read off the status the Mail stamps. Recomputed rather than accumulated: the
        -- Mail's own bonus is monotonic and restated every blow, so tracking a delta here would drift
        -- against it. `applied` holds what has been granted so far and only the difference is added.
        local rage = 0
        local wrath = Status.get(ctx.unit, "status_wrath")
        if wrath then
            rage = math.floor((wrath.magnitude or 0) / ctx.def.share)
        end

        local want = base + rage
        local have = ctx.trait.applied or 0
        if want <= have then return end
        ctx.addBonus("defense", want - have)
        ctx.trait.applied = want
    end,
}
