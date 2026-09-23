-- THE SLOW CIRCLE: the lamia's tether with the player's name on it. What the bearer's melee bites,
-- cannot get away from the bearer.
--
-- THE RIFT SELLS YOU THE TRICK, which is the ordering Marrowlight argues and the third time this
-- circle has done it: a rule that puts a string on somebody is strange handed cold at a counter and
-- ordinary handed over by the corpse of the thing that spent a fight doing it to you.
--
-- NOBODY ELSE BINDS A FOE TO *YOU*, which is the gap it was authored into. weapon_sworn_lance swears
-- two FOES to each other -- Acedia's rule, sold back to a knight -- and the leashes
-- (utility_beastlords_bond, utility_second_leash) hold a SUMMON to its summoner. A tether from your
-- own body to somebody else's is a thing the catalogue did not have.
--
-- WHAT IT IS FOR is the fight a melee body cannot otherwise have: something that kites. An archer, a
-- skirmisher, anything with a free move after it swings -- all of them beat a sword by never being
-- where it is, and this makes the not-being-there the expensive part. It does not stop them leaving
-- and is not meant to; Root already does that and does it for one turn.
--
-- MELEE ONLY, and the reason is the same one The Updraught's is: a rider that costs nothing to apply
-- from four tiles away is a rider nobody ever decides about. You have to get in.
--
-- ON A COOLDOWN, unlike the two harpy drops beside it, because this one does not expire. Coiled has no
-- clock -- it runs until the bearer falls or a Cure cuts it -- so an untimed application on every
-- landed blow would have a bearer holding the entire far side by the third turn, which is not a
-- decision, it is a mop. Ten ticks means two of them at once and a choice about which two.
--
-- ONE SHADOWING TO KNOW ABOUT: inside onCast, `ctx.item` is the item that was just CAST, not the item
-- this trait came off -- an event field of that name shadows the granter (models/trait.lua says so at
-- the dispatcher).
return {
    name = "The Slow Circle",
    description = "Your melee blows tether a foe to you. It pays to end its turn away from you.",
    cooldown = 10,
    onCast = function(ctx)
        if (ctx.damageDealt or 0) <= 0 then return end
        local cast = ctx.item -- the weapon that just swung: see the shadowing note above
        if not (cast and cast.activeAbility) then return end
        local melee = false
        for _, tag in ipairs(cast.tags or {}) do
            if tag == "melee" then melee = true break end
        end
        if not melee then return end
        local foe = ctx.unitAt(ctx.tx, ctx.ty)
        if not foe or not foe.alive or foe.side == ctx.unit.side then return end
        -- Already held by this bearer: spend nothing and stay off cooldown, so a second blow on the
        -- same body is not silently the worst turn the item has. Keyed cooldowns, like trait_lure's.
        if require("models.status").get(foe, "status_coiled") then return end
        if ctx.onCooldown("trait_the_slow_circle") then return end
        ctx.setCooldown("trait_the_slow_circle", ctx.def.cooldown or 10)
        local st = ctx.applyStatus(foe, "status_coiled")
        if st then st.coiler = ctx.unit end -- what the tether measures from (see status_coiled)
        ctx.log("action", string.format("%s puts a circle around %s.",
            (ctx.unit.char and ctx.unit.char.name) or "Unit",
            (foe.char and foe.char.name) or "its quarry"), { ctx.unit, foe })
    end,
}
