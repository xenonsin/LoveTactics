-- Greenstep: the Nymph steps into her own grove and out of it again wherever it puts the most ground
-- between her and whoever is chasing her.
--
-- IT WAS TREE-STRIDE, AND TREE-STRIDE WANTED WALLS. The first cut stepped between any two tiles beside
-- a wall, and a fight board has almost none. So the grain is the grove's own now (models/grove.lua):
-- her saplings, her sister's hedges, the thorn floor, the Hamadryad's tree. No grove, no step -- which
-- is why she plants first (weapon_seedfall).
--
-- SELF-AIMED, because a creature's escape has one right answer and the planner should not have to find
-- it by scoring tiles: of every free tile beside a plant of hers, the one farthest from every foe
-- (Grove.farthestFrom). The company's version picks its own tile (ability_greenstep).
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Into the Green", -- not the spell's name (ability_greenstep): see weapon_mistlight on why
    description = "Steps into her grove and out beside the plant farthest from every foe.",
    flavor = "She was never in front of you. You were looking at the tree.",
    sprite = "assets/items/greenstep.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "nature", "magical" },
    noSteal = true,
    activeAbility = {
        target = "self",
        support = true,
        range = 0,
        speed = 3,
        cost = { stat = "mana", amount = 6 },
        ai = {
            { priority = "high", act = "cast", when = { subject = "any_foe", test = "within", value = 1 } },
        },
        effect = function(fx)
            local Grove = require("models.grove")
            local user = fx.user
            local exits = Grove.exits(fx.combat, user.side)
            local best = Grove.farthestFrom(fx.combat, exits, function(u) return u.side ~= user.side end)
            if not best then
                fx.log("action", string.format("%s reaches for the grain and finds none.", user.char.name or "She"))
                return
            end
            fx.teleportUser(best.x, best.y)
        end,
    },
}
