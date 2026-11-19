-- The Longfang's Hunt: the pride leader's rule, and since 2026-11-19 a rule about HER CATS rather than about
-- her (the creature identity pass, "same-pounce"). The audit found the Sabertooth and the Longfang one loop:
-- both pounced out of Invisible, both struck back, and she added one sentence. So they were split.
--
--   * The Sabertooth is the ambusher: hide a turn, pounce, stand exposed for the round.
--   * The Longfang does not hide at all (no Tawny Hide). She stands in the open at the head of the pride,
--     strikes back when struck (Feral Instinct, which is hers alone now), and while she stands, a cat of
--     hers within `radius` that DOWNS a body from hiding stays hidden -- through the round it has just
--     earned and into its next turn. That is The Unbroken Stalk's rule, lent to the pride.
--
-- SO THE PRIDE IS AN ORDER QUESTION. Leave her standing and every kill a cat makes is a cat you never see;
-- kill her first -- the one body on the board that is always in plain sight, and that hits back -- and the
-- cats are ordinary ambushers again. The old answers still hold for the cats themselves: keep everyone above
-- one critical bite, and an area blast or Witchlight reaches a hidden cat.
--
-- TWO HALVES, as The Unbroken Stalk has. The Pounce asks `lendsVeilOnKill` on any ally within `radius` at the
-- bite, and keeps the cat's cover on a kill (data/items/weapon/weapon_pounce.lua). Then onAnyDeath, which
-- hears the fall once the action has finished, latches the still-hidden cat's `veilNext`, which
-- Combat.startTurn spends -- so the kept veil lasts into the next turn rather than lapsing at its top.
return {
    name = "The Longfang's Hunt",
    grade = 1.0, -- weighed beside the rule (Grade.traitValue reads it): a cat's veil kept through one kill, while she stands
    description = "An ally within 3 tiles that downs a foe while Invisible stays Invisible, into its next turn.",
    radius = 3,
    lendsVeilOnKill = true,
    onAnyDeath = function(ctx)
        local fallen, me = ctx.fallen, ctx.unit
        if not (fallen and me and me.alive) then return end
        local killer = fallen.lastAttacker
        if not (killer and killer ~= me and killer.alive and killer.side == me.side
            and fallen.side ~= me.side) then return end
        local Status = require("models.status")
        if not Status.has(killer, "status_invisible") then return end
        -- The same measure the Pounce's half asks (the larger of the two axes), so the two halves can never
        -- disagree about who stood close enough.
        local gap = math.max(math.abs(me.x - killer.x), math.abs(me.y - killer.y))
        if gap > ((ctx.def and ctx.def.radius) or 3) then return end
        killer.veilNext = true
    end,
}
