-- SWARM FORM: the Thousand-Winged's drop (Wrath's vampires, round 3: "you come apart into bats and move up to 6
-- tiles, straight through bodies, and every foe you pass over Bleeds. You re-form where you stop.").
--
-- The flight is a route, not a line: up to six steps over open ground, through anyone standing on it, and of the
-- shortest routes to the tile it takes the one over the most foes (models/swarm.lua's Swarm.formPath). The route
-- is painted as the ability's area, so what the board shows before the cast is who will bleed. Every foe on it
-- Bleeds, and the wound is the caster's (Status.apply's `applier` -> the Bleed's `opener`), so a vampire's Thirst
-- drinks what they lose on the run. It comes down only on a free tile, as a leap does: it springs where it lands
-- and nothing it crossed.
--
-- A SKIRMISHER's, because the house that prices where it stands is the one that wants to be somewhere else.
-- `unstocked`: a trophy, off the swarm's bats and nowhere else (tests/discovery_spec.lua names it).
local REACH = 6

return {
    name = "Swarm Form",
    description = "Come apart into bats and fly up to 6 tiles, through bodies, to a free tile. "
        .. "Every foe you pass over Bleeds.",
    flavor = "The cloak falls empty. Something with a hundred mouths goes past you at head height.",
    sprite = "assets/items/ability_swarm_form.png",
    type = "ability",
    tags = { "movement", "flying" },
    class = "skirmisher",
    unstocked = true,
    unlockLevel = 7,
    activeAbility = {
        target = "tile",
        range = REACH,
        speed = 3,
        support = false, -- a move that wounds: the route paints red
        cost = { stat = "stamina", amount = 8 },
        aoe = {
            cells = function(combat, tx, ty, unit)
                local path = unit and require("models.swarm").formPath(combat, unit, tx, ty, REACH)
                return path or { { x = tx, y = ty } }
            end,
        },
        effect = function(fx)
            local path = fx.combat and require("models.swarm").formPath(fx.combat, fx.user, fx.tx, fx.ty, REACH)
            if not path then
                fx.log("action", "The bats cannot find a way there.")
                return
            end
            local seen = {}
            for _, c in ipairs(path) do
                local u = fx.unitAt(c.x, c.y)
                if u and u ~= fx.user and u.alive and u.side ~= fx.user.side and not seen[u] then
                    seen[u] = true
                    fx.applyStatus(u, "status_bleed")
                end
            end
            fx.teleportUser(fx.tx, fx.ty, { glide = true })
        end,
    },
}
