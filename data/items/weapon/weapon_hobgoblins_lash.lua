-- THE HOBGOBLIN'S LASH: the Hobgoblin's whip, and the drop off it (approved as pitched, 2026-09-26, "The
-- Goblins of Wrath"). It hits foes like a whip at reach 2. It can also LASH AN ALLY: they lose 10% of their
-- health and take an extra turn right away (fx.grantExtraAction + fx.hasten, the pair the fx table names for
-- "let another body act again"). The lash on an ally has a three-turn cooldown of its own, kept on the
-- bearer, so the whip keeps swinging at foes in between.
--
-- A haste bought with a friend's blood. `target = "unit"`: a player aims it anywhere; the planner is offered it
-- only at foes (`aiFoes`), and the Hobgoblin plans the ally half as its own support cast (ability_the_lash).
local Curve = require("models.curve")

local ALLY_COOLDOWN = 15 -- three turns
local ALLY_TOLL = 0.10

return {
    name = "Hobgoblin's Lash",
    description = "Whips a foe at reach 2. Or lash an ally: it loses 10% of its health and acts again at once (3-turn cooldown).",
    flavor = "Every goblin in the warband has felt it. Every one of them went faster.",
    sprite = "assets/items/weapon_hobgoblins_lash.png",
    type = "weapon",
    -- The DAGGER family (docs/weapons.md): there is no whip family, and a lash is the quick, bleeding cut --
    -- a dagger's contract (speed 2 or less), at a whip's reach.
    tags = { "dagger", "slash", "physical", "melee" },
    class = "warlord",
    unlockLevel = 8,
    unstocked = true,
    activeAbility = {
        target = "unit",
        aiFoes = true,
        range = 2,
        speed = 2,
        cost = { stat = "stamina", amount = 7 },
        damage = Curve.ramp(10, 20),
        effect = function(fx)
            local target, user = fx.target, fx.user
            if not (target and target.alive) then return end
            if target.side ~= user.side then fx.damage(target) return end
            if target == user or (user.lashReadyAt and fx.combat.clock and fx.combat.clock < user.lashReadyAt) then
                return
            end
            local Combat = require("models.combat")
            local toll = math.max(1, math.floor(Combat.unreservedMax(target.char, "health") * ALLY_TOLL + 0.5))
            fx.flatDamage(target, toll, { "slash" })
            fx.grantExtraAction(1, target)
            fx.hasten(target, 1.0)
            fx.bank("lashReadyAt", (fx.combat.clock or 0) + ALLY_COOLDOWN)
        end,
    },
}
