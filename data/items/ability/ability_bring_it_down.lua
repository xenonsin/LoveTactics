-- Bring It Down: the Saboteur's demolition (rogue x alchemist). Destroys a wall or a piece of furniture
-- and leaves the rubble as ground nobody crosses comfortably.
--
-- NAMED AROUND an existing item, and recorded rather than hidden: this was drafted as "Collapse", which
-- data/items/ability/ability_collapse.lua has owned since before the disciplines existed -- a mage
-- ability that folds the world inward and drags the enemy line onto the caster. Same precedent as
-- "Shadow Step" -> "Shadow Trade" and "Duelist's Edge" -> "Duelist's Poise": the deeper cut yields the
-- name to the shelf a player meets first.
--
-- It is the Saboteur's third leg and the only one not about timing. Detonator and the Sapper's Line are
-- both decisions about a turn that has not happened yet; this is the saboteur's answer to a BOARD -- the
-- wall your enemy is sheltering behind, the barricade holding your line out, the keg somebody
-- thoughtfully left in a doorway.
--
-- It refuses an empty tile rather than doing something vague with it. A demolition needs a thing to
-- demolish, and an ability that quietly did nothing on a miss is one the player learns to distrust.
--
-- The rubble is quicksand: churned, sucking ground that Mires whatever stands in it. That is what a
-- collapsed structure IS mechanically -- the wall stops being cover and becomes an obstacle, which is a
-- different and usually better thing for the person who brought the explosives.
return {
    name = "Bring It Down",
    description = "Destroys a wall or object and leaves the rubble as treacherous ground.",
    flavor = "Load-bearing is a property of the building. It is not a property of the plan.",
    sprite = "assets/items/ability_bring_it_down.png",
    type = "ability",
    tags = { "impact" },
    class = "alchemist",
    discipline = "saboteur",
    price = 610,
    unlockQuests = 4,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 4,
        cost = { stat = "mana", amount = 9 },
        description = "Brings down a wall or object on the aimed tile and churns the ground it stood on.",
        effect = function(fx)
            local Wall = require("models.wall")
            local wall = Wall.at and Wall.at(fx.combat, fx.tx, fx.ty)
            local obj, kind = fx.objectAt(fx.tx, fx.ty)
            if not wall and not obj then
                fx.log("action", "There is nothing there to bring down.")
                return
            end
            if wall then
                wall.alive = false
                wall.health = 0
            elseif obj then
                -- Hit hard enough to finish anything standing: a keg detonates, a crate splinters.
                require("models.combat").damageObject(fx.combat, obj, kind, 9999)
            end
            fx.placeHazard(fx.tx, fx.ty, "hazard_quicksand",
                { amount = 4 + fx.level, duration = 10 + fx.level })
        end,
    },
}
