-- BEREFT: the sow's rule with the cub taken out of it, which is what makes it carryable.
--
-- trait_bereaved is hers and reads one blueprint: her cub, once, by name. A company has no cub, so the
-- player's version asks the question the fight actually asked -- what do you do when the thing you were
-- keeping alive stops being alive -- and answers it the same way she did.
--
-- NOT trait_blood_fever, AND THE DIFFERENCE IS THE WHOLE ITEM. Blood Fever counts every body that hits
-- the ground on EITHER side, two Damage at a time, up to five: a thing you feed by winning, and one an
-- ordinary fight tops out on its own. This counts only your own, once, for a larger number -- so it can
-- never be farmed, it pays exactly when a run is going badly, and a company that plays perfectly never
-- sees it fire. That is the sow's bargain from the other side of the board, and a trait whose best case
-- is one you would not have chosen is a different object from one you build toward.
--
-- ONCE, AND PERMANENT FOR THE BATTLE. `stacks` is the latch, the same way trait_bereaved latches. A
-- per-body version would turn a collapsing line into a snowball and reward the thing it is meant to
-- console you for; one body is grief, four is a strategy.
--
-- Fires on onAnyDeath rather than onDeath, because the body that falls is not the bearer -- and it reads
-- the FALLEN's side rather than counting allies, so a charmed companion cut down while fighting for the
-- other team is not counted. It was not yours when it fell.
return {
    name = "Bereft",
    description = "The first ally to fall permanently raises your Damage this battle.",
    -- Six, against a mid-campaign Damage in the high teens: about a third again, permanently, on a
    -- trigger you cannot choose to pull. Her own is 10 on 22 (trait_bereaved) and is priced for a boss
    -- whose fight ends when she does; this has to sit in a company's grid for a whole campaign, so it is
    -- the smaller number of the two.
    magnitude = 6,
    onAnyDeath = function(ctx)
        local fallen, u = ctx.fallen, ctx.unit
        if not (fallen and u and u.alive) then return end
        if fallen == u then return end          -- it is not about you
        if fallen.side ~= u.side then return end -- and their dead are not your loss
        if (ctx.trait.stacks or 0) > 0 then return end -- once: see the header
        ctx.trait.stacks = 1
        ctx.addBonus("damage", ctx.def.magnitude)
        ctx.log("action", string.format("%s has nothing left to be careful with.",
            (u.char and u.char.name) or "Unit"))
    end,
}
