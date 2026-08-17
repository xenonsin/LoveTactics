-- Cael's bound relic (Necromancer). He reads the thread backwards, and the price is the work he had
-- already done.
--
-- ZOMBIES ARE THE CURRENCY, NOT CORPSES, and the difference is the whole design. A corpse is something
-- the fight handed him -- gating on corpses charged him nothing and paid out exactly when the board
-- was already full of his kills, which is the "win more" shape. The undead he raised are something he
-- BUILT: Raise Dead and Early Rites go from competitors for the same bodies to required purchases,
-- because nothing else mints what this spends.
--
-- AND IT IS UTILITY RATHER THAN A BIGGER ARMY. The relic gives a fallen comrade back. That is the one
-- thing a necromancer reaches for while LOSING, which is the moment a signature should exist for --
-- the whole court he has been assembling goes back down so that one of the living stands up.
return {
    name = "The Second Reading",
    description = "Every zombie you raised goes back down, and an ally who fell this fight stands up.",
    flavor = "The first reading was for the dead. This one is for somebody he would rather have kept.",
    sprite = "assets/items/sig_second_reading.png",
    type = "utility",
    tags = { "signature", "dark" },
    class = "mage",
    discipline = "necromancer",
    bound = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 7,
        cost = { stat = "mana", amount = 16 },
        description = "Spends every zombie you hold to return one fallen ally.",
        unlock = {
            field = { of = "unit", summoned = true, count = 3 },
            text = "3 of your undead standing",
        },
        effect = function(fx)
            -- Find the body first. If nothing of his has fallen there is nothing to buy, and the court
            -- should not be spent on it -- a relic that ate its own army for no return would be a trap
            -- rather than a decision.
            local fallen
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if not u.alive and u.side == fx.user.side and u.summoner == nil then
                    fallen = u
                    break
                end
            end
            if not fallen then return end
            if not fx.reanimate(fallen, 0.5) then return end
            -- Paid for afterwards, and only once the reading has actually taken.
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.summoner == fx.user then fx.dismiss(u) end
            end
        end,
    },
}
