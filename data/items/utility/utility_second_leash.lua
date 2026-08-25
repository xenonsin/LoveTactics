-- Tola's bound relic (Beastmaster). She brings one more body than she is counted for, and this is what
-- stops the fight taking them back.
--
-- THE CENSUS IS THE BUILD: three beasts standing. Summon Wolf and the Falconer's Glove are how the
-- count gets there, Beastlord's Bond is how it stays there, and both matter far more once the number
-- is the thing she is protecting. A beastmaster fielding one animal cannot press this at all.
--
-- NOT A SECOND TURN. An earlier draft gave the pack an extra action, which pays out when she is
-- already winning -- the "win more" shape. This pays out in DURABILITY instead: each beast is braced,
-- and each is emboldened by every other one still on its feet. The pack is worth more than the animals
-- because it is a pack, which is the only thing a beastmaster believes.
return {
    name = "The Second Leash",
    description = "Braces every beast you field, and each is emboldened by the others still standing.",
    flavor = "One leash is an animal you own. Two is a pack that has decided to stay.",
    sprite = "assets/items/sig_second_leash.png",
    type = "utility",
    tags = { "signature", "primal" },
    class = "hunter",
    discipline = "beastmaster",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "stamina", amount = 10 },
        description = "Braces your beasts, each gaining force per other beast standing.",
        unlock = {
            field = { of = "unit", summoned = true, count = 3 },
            text = "3 beasts standing",
        },
        effect = function(fx)
            -- Count first, then buff: every animal is emboldened by how many OTHERS are up, so the
            -- pack has to be measured before any of it is changed.
            local pack = {}
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.summoner == fx.user then pack[#pack + 1] = u end
            end
            for _, beast in ipairs(pack) do
                fx.applyStatus(beast, "status_defending")
                fx.applyStatus(beast, "status_empowered", { magnitude = 3 * (#pack - 1) })
            end
        end,
    },
}
