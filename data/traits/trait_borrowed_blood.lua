-- BORROWED BLOOD: every blow a body she has taken lands on its own line feeds her.
--
-- IT IS THE CLOCK, AND WITHOUT IT THE CHARM IS ONLY AN INCONVENIENCE. A turned body swings at the
-- company for two turns and comes back; annoying, survivable, and a party that simply waits it out has
-- answered the Abbess by doing nothing. This makes waiting cost: the longer your anvil is hers, the
-- healthier she gets, and the health is coming off the line it is swinging at. **She never lifts a
-- hand. She is fed by what you do to each other.**
--
-- ONLY FROM WHAT SHE HOLDS. Gated on the victim carrying Charm with the bearer stamped as its
-- `charmer`, so her own flock's swings feed her nothing -- a succubus standing beside her is not a
-- congregation, it is an ally, and a rule that paid out for ordinary chaff hitting the party would be
-- a lifesteal aura wearing a charm's name.
--
-- A FLAT SIP, NOT A SHARE OF THE DAMAGE. onAllyStrike does not carry what the blow dealt (models/trait.lua
-- -- it reports the OPENING, which is what a follow-up hangs on), and reaching for the number would mean
-- widening a hook five other reflexes read for something only this wants. A flat figure is also the
-- better rule: it prices the TURN she has taken rather than the weapon the body she took happens to be
-- holding, so charming the mace does not pay her more than charming the knife.
--
-- IT PAIRS WITH THE CONGREGATION AND THE TWO ARE DELIBERATELY NOT THE SAME SENTENCE. The Congregation
-- is what happens when you hit HER; this is what happens when you do not. Together they close the
-- fight's two obvious doors -- swing at her and it lands on your own, leave her alone and she drinks --
-- and leave open the two the circle intends: free the body, or reach her.
--
-- A tenth of a line body's health per blow, roughly, which is a sip and not a meal: three turns of a
-- charmed anvil working the line is most of an elite's own melee hit given back. The pacing is the
-- charm's clock, not a cooldown -- a rule that already ends on its own timer does not need a second one.
return {
    name = "Borrowed Blood",
    description = "Heals you whenever a foe you have Charmed strikes.",
    magnitude = 5,
    onAllyStrike = function(ctx)
        local striker = ctx.ally
        if not (striker and striker.alive) then return end
        local Status = require("models.status")
        local st = Status.get(striker, "status_charm")
        if not (st and st.charmer == ctx.unit) then return end
        local healed = ctx.heal(ctx.unit, ctx.def.magnitude or 5)
        if healed and healed > 0 then
            ctx.log("status", string.format("%s drinks what %s just did (+%d).",
                (ctx.unit.char and ctx.unit.char.name) or "She",
                (striker.char and striker.char.name) or "her own", healed), ctx.unit)
        end
    end,
}
