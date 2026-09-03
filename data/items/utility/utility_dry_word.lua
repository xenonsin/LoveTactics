-- Ivo's bound relic (Spellbreaker). Not a fight a caster picks -- a condition they walk into.
--
-- EMPTY VESSEL EXECUTES THE MANA-DRY, and this is what makes them dry: the two are one engine, and
-- neither is worth much alone. Silencing Blade and The Gagging Storm are how three casters come to be
-- silenced at the same time, Dampening Oath doubles what a cast costs on the way in, and Spell Eater
-- banks what is drained. The whole shelf is six passives and a condition; this is the condition made
-- deliberate.
--
-- THE CENSUS IS THREE SILENCED, which is the right shape for exactly the reason a tally would be the
-- wrong one: what has to be true is that the enemy's casters are shut up RIGHT NOW, all at once, and
-- that state can be lost. Silence one at a time across six turns and the relic never opens.
return {
    name = "The Dry Word",
    description = "Drains the mana of every silenced foe within 3, and hands it to you.",
    flavor = "He does not argue with them. He waits until there is nothing left to argue with.",
    sprite = "assets/items/sig_dry_word.png",
    type = "utility",
    tags = { "signature", "arcane" },
    class = "knight",
    discipline = "spellbreaker",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "stamina", amount = 10 },
        aoe = { radius = 3, shape = "square" },
        description = "Empties every silenced foe caught, restoring the mana to you.",
        unlock = {
            field = { of = "unit", side = "foe", status = "status_silenced", count = 3 },
            text = "3 foes Silenced",
        },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side and fx.hasStatus(u, "status_silenced") then
                    -- Drained rather than burned: what leaves them arrives on him, which is what makes
                    -- this a spellbreaker's relic and not an anti-mage hazard. fx.drain hands back
                    -- exactly what it took, so the two halves can never disagree.
                    local taken = fx.drain(u, "mana")
                    if taken > 0 then fx.restore(fx.user, "mana", taken) end
                end
            end
        end,
    },
    -- taking a caster's mana and keeping it
    bonus = { magicDefense = 2 },
}
