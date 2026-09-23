-- THE FIRST YES: the Abbess walks onto the board already holding one of you.
--
-- WHY IT IS FREE AND WHY IT IS NOT A ROLL. Her cast is a roll and a kind one -- Status.charmChance pays
-- 25% against a whole body and only climbs as that body is ground down (weapon_the_anointing) -- which
-- is correct for the thing she spends the fight doing and completely wrong for the OPENING. A fight
-- whose entire shape depends on a coin landing is a fight the player meets a different version of every
-- time, and the two rules stacked on this body (data/traits/trait_the_congregation.lua and
-- trait_borrowed_blood) read as nothing at all on a board where nobody is charmed. She has to be
-- holding somebody at the bell, or the Chapel opens as an ordinary fight and then abruptly becomes a
-- different one two turns in.
--
-- SHE TAKES THE BIGGEST, DELIBERATELY, AND IT IS THE ONE PLACE THIS CIRCLE PICKS ON THE STRONG.
-- Everything else on the stratum reaches for whoever is already giving way -- the Matriarch's cry is
-- `lowest_hp`, the charm's own curve pays out best against a body nearly down. This is the inversion,
-- and it is what makes her memorable: the company's anvil is hers before anybody has swung. Read off
-- max health rather than current, because it is a fact about which body the party BUILT and not about
-- how the walk down went.
--
-- DECIDED, NOT DRAWN. Highest max health wins, ties break on the order the units were seated, so one
-- seed lays out one Chapel (models/descent.lua's whole premise -- a floor is a place, not a roll).
--
-- IT WALKS THE LINE UNTIL SOMEBODY ANSWERS. Status.apply refuses a body that is warded against Charm
-- (utility_untroubled_mind's `statusImmunity`) and a quest objective outright (status_charm's
-- `bossProof`), and both refusals hand back nil -- so a company that armoured its anvil against exactly
-- this does not switch the rule off, it MOVES it, and the second-biggest answers instead. A company
-- that warded everybody has genuinely bought the opening, which is a real reward for a real decision.
--
-- AND THE RELEASE IS UNCHANGED. Cut her and everyone she holds comes home mid-turn
-- (Combat.releaseCharmedBy) -- the stratum's own law, and the reason this is an opening rather than a
-- sentence: it is worth exactly as much as the time it takes the company to reach her.
--
-- ONCE. onCombatStart fires once per battle by construction (Trait.setup), so there is no re-arm to
-- guard against and no latch to keep.
return {
    name = "The First Yes",
    description = "Opens the fight with one foe already Charmed -- the one with the most health.",
    onCombatStart = function(ctx)
        local ours = ctx.unit.side
        local ranked = {}
        for _, u in ipairs(ctx.combat.units or {}) do
            if u.alive and u.side ~= ours then ranked[#ranked + 1] = u end
        end
        -- Stable: the seating order is the tie-break, so the same seed opens the same way.
        local order = {}
        for i, u in ipairs(ranked) do order[u] = i end
        table.sort(ranked, function(a, b)
            local ah = (a.char and a.char.stats and a.char.stats.health and a.char.stats.health.max) or 0
            local bh = (b.char and b.char.stats and b.char.stats.health and b.char.stats.health.max) or 0
            if ah ~= bh then return ah > bh end
            return order[a] < order[b]
        end)
        for _, u in ipairs(ranked) do
            -- The APPLIER is what makes it a taking rather than a badge: status_charm reads it to
            -- decide whose side the body now stands on, stamps it as the `charmer`, and hands the body
            -- back from exactly that name when she falls (Combat.releaseCharmedBy). Without it the
            -- fallback turns the victim on its own line and nobody owns the release.
            if ctx.applyStatus(u, "status_charm", { applier = ctx.unit }) then
                ctx.log("status", string.format("%s says her name before the fight starts.",
                    (u.char and u.char.name) or "Somebody"), u)
                return
            end
        end
    end,
}
