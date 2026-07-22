-- Clem's signature, and the counterplay to Aurea written as tempo (docs/story.md, "The Undercroft").
-- Time is money, and she gives it away. Where the general BUYS time -- every summon and action she pays
-- for out of her hoard -- Clem MINTS it and hands it to the party, keeping none.
--
-- A blade, like Saber's First Motion, so the killer's own tool sits at the grid's centre (never a
-- cleanse, which is the priest's verb, not the rogue's). Two parts, the way Rowan's Aegis and Kaya's
-- Horn are:
--
--   * THE MERCY-STROKE (active): a coup on a wounded foe -- her name in a verb (clementia -> coup de
--     grace) -- that secures the kill, and in the same motion QUICKENS the whole party (status_hasted).
--     Her lethality is everyone's tempo; she keeps none of the haste for herself, it is spent on the team.
--   * THE GATE (conditional-unlock): it charges on the shipped `kill` tally (unlock.event = "kill"), so
--     she must be doing the work -- softening with poison, collecting the kill -- before the marquee
--     opens. The signature system greys it with a "Collected (n/3)" badge and re-locks after each use
--     (Combat.unlockMet / itemBlockReason), exactly as the Ledger and the Horn do.
--
-- SHIPPED FIDELITY: the haste rides in the stroke's effect rather than on a passive kill-hook (the engine
-- dispatches no onKill), so the party quickens when she spends the coup, not on every incidental kill.
-- The fully-passive haste-on-any-kill and the slot-8 KEEP-THE-TEMPO second form (she keeps one kill's
-- haste for herself) are deferred new work (see the chapter).
--
-- `bound = true` (models/item.lua): never moved, stowed, given, sold, or stolen -- only forged. No `price`;
-- `class = "rogue"` still tallies rogue growth.
return {
    name = "Borrowed Time",
    description = "Collect three kills, then a mercy-stroke on a wounded foe that quickens the whole party.",
    flavor = "Time is money, and she is the one debtor in the city who gives it away. She keeps none of it.",
    sprite = "assets/items/sig_borrowed_time.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "melee", "signature" },
    bound = true,
    class = "rogue",
    activeAbility = {
        description = "A heavy coup on a foe, striking far harder the lower its health -- and the whole party is Hasted.",
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 8 },
        unlock = { event = "kill", count = 3, text = "Collected" },
        damage = { 12, 13, 15, 16, 18, 19, 21, 22, 24, 25, 27 },
        effect = function(fx)
            -- The coup: it lands harder the closer the foe is to the ground (the mercy-stroke finds the
            -- opening the party's poison already opened -- the inverse of Saber's front-load).
            local hp = fx.target and fx.target.char.stats.health
            local frac = (hp and hp.max and hp.max > 0) and ((hp.current or 0) / hp.max) or 1
            local coup = math.floor(fx.amount * 0.6 * (1 - frac))
            fx.damage(fx.target, { amount = fx.amount + coup })
            -- She spends the kill on everyone: the whole party quickens, and she keeps none of it.
            for _, u in ipairs(fx.combat.units) do
                if u.alive and u.side == fx.user.side then fx.applyStatus(u, "status_hasted") end
            end
        end,
    },
}
