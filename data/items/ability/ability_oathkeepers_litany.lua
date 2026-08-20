-- Oathkeeper's Litany: the Paladin's ward aura (knight x priest). Every ally standing beside the paladin
-- is braced -- the damage-reduction stance a knight normally has to spend its own turn taking, handed to
-- the whole rank at once.
--
-- The distinction against the Aegis of the Oath, which the shelf already sells: that is incense, ground
-- that walks with the paladin and protects whoever happens to be standing in it at the time. This is a
-- CAST, and what it grants goes with the ally rather than staying with the paladin. So the two answer
-- opposite questions -- the incense says stay near me, the litany says go, and take this.
--
-- Braced via status_defending, which is the same protection the Defend action buys. That is deliberate
-- rather than a shortcut: the litany's whole pitch is that it hands out a thing the party would
-- otherwise each have to spend a turn on, so it had better be exactly that thing. A paladin trading one
-- of its turns for three of theirs is the arithmetic the ability lives or dies by.
--
-- Skips the paladin itself. A litany is said FOR somebody, and a knight that could brace itself and the
-- line in one action would make Defend a dead button on its own shelf.
return {
    name = "Oathkeeper's Litany",
    description = "Braces every ally beside you against the next blows they take.",
    flavor = "He does not raise his voice for it. The ones who need to hear it are already close.",
    sprite = "assets/items/ability_oathkeepers_litany.png",
    type = "ability",
    tags = { "holy" },
    class = "priest",
    discipline = "paladin",
    price = 210,
    unlockQuests = 1,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 4,
        support = true,
        cost = { stat = "mana", amount = 10 },
        description = "Grants every adjacent ally a bracing ward.",
        effect = function(fx)
            local said = 0
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 1)) do
                if u.alive and u.side == fx.user.side and u ~= fx.user then
                    fx.applyStatus(u, "status_defending", { magnitude = 6 + fx.level })
                    said = said + 1
                end
            end
            if said == 0 then fx.log("action", "The litany is said to nobody in particular.") end
        end,
    },
}
