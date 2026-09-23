-- THE LADY CHAPEL: the Lust circle's third elite, and the only fight on the stratum you cannot open by
-- hitting the thing you came to kill.
--
-- WHAT IT ASKS IS NOT "CAN YOU REACH HER". The Eyrie takes the choice of where to stand away; the
-- Drowned Stair prices every tile you move. This takes the SWING. The Abbess walks on holding three
-- people -- two of the Cathedral's own, blooded and standing with her since before the bell
-- (trait_the_blooded), and the biggest body in the company, taken at the bell and unrolled
-- (trait_the_first_yes) -- and every wound meant for her opens in all three of them instead
-- (trait_the_congregation). The company can reach her on turn one. What it cannot do is hit her, and
-- working out why is the fight.
--
-- SO THE ANSWER IS THE STRATUM'S OWN LAW, AND THIS IS WHERE IT FINALLY COSTS SOMETHING. "Cut the one
-- doing it" has been true of this circle since it was re-premised -- a charm ends with its charmer, a
-- jeer with its taunter, a coil with the serpent -- and it has always been free advice, because cutting
-- the one doing it was a matter of walking over. Here she is standing behind your own anvil and two
-- people in plate. Cure your own and take a place off the split; wait the Charm out on the body she
-- took; silence her relic (Sunder takes the opening and the split together, since both ride
-- utility_the_anointed); or cut through the congregation knowing that every blow they land is feeding
-- her (trait_borrowed_blood). Four keys, all of them things a company already carries, none of them
-- the thing a company reaches for first.
--
-- AND THE PAYOFF IS THE WHOLE ROOM. The two blooded have no side of their own left, so when she falls
-- their binding does not revert -- it ENDS, and they come back to themselves and walk out
-- (status_charm's onExpire). A company that goes straight at her wins a fight that looked like five
-- bodies in two turns. That is the largest reward this circle's law has ever paid, and it is sitting on
-- the floor where the law is hardest to follow.
--
-- HER OWN LINE AND THE CHURCH'S, AND NOBODY ELSE'S. The Drowned Stair's argument holds here: an escort
-- of one kind means every body on the board is pulling the same direction and the slope is legible.
-- Mixing harpies in would deliver her damage for free -- a real interaction on a floor that rolls both
-- stops -- but as an AUTHORED cast it would teach the wind and the congregation in one breath and
-- neither cleanly.
--
-- A SPARE RATHER THAN A BILLING, deliberately. Descent.SINS bills this circle's two rungs to its two
-- ANIMALS on purpose -- the coils hold the approach and the wings hold the seat, cheapest rule first --
-- and an argument that careful is not worth unpicking to seat a third. She turns up at ELITE_WEIGHT on
-- either floor instead (Descent.floorPool's elite branch keeps the unnamed ones legal so a circle's
-- spares still appear), which is the correct rarity for the thing that is not what the stratum is
-- ABOUT but is the worst thing standing in it.
--
-- See encounter_lust_the_long_gallery for why there are human bodies on a floor the 2026-09-22 sweep
-- cleared of them, and what the distinction is.
--
-- Locked to the castle stratum by ctx.biome, the same gate every circle uses.
local Band = require("models.band")

return {
    name = "The Lady Chapel",
    kind = "elite",
    weight = 1, -- rarest thing on the floor: the body a stratum is remembered for
    condition = function(ctx) return ctx.biome == "castle" end,
    -- RUNG 2, beside the Eyrie. Heaviest of the castle's four measured, and the floor where "cut
    -- the one doing it" -- this circle's standing law, free advice everywhere else -- finally has
    -- to be paid for. One elite, one floor: see models/encounter.lua's eligibility note.
    rung = 2,
    composition = function(ctx)
        -- Her and one rung below her, then the congregation. The ladder the player climbed to get here,
        -- standing on one board.
        local list = { "character_succubus_abbess", "character_succubus" }
        Band.fill(list, ctx, "character_knight", { base = 1, per = 7, max = 2 })
        return Band.fill(list, ctx, "character_priest", { base = 1, per = 7, max = 2 })
    end,
}
