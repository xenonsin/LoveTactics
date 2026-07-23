-- Scouring Mercy: the priest burns the ally first, and then mends them for considerably more, slowly.
-- Cast at an enemy it is simply fire with an insult attached -- the mending goes to them too, which is
-- rarely what anybody wanted.
--
-- A HEAL THAT COSTS THE PATIENT SOMETHING, and the reason to build one is arithmetic the Cathedral's
-- other spells cannot do. A direct heal is instant and safe and therefore priced modestly. This one
-- pays out over the clock (`status_regen`), which means it is worth MORE in total and worth NOTHING if
-- the target dies in the meantime -- and it opens by taking them closer to that. So it is the mend you
-- cast on somebody who is hurt but not in danger, and never on somebody who is about to fall.
--
-- Which is precisely the gap in the priest's kit. Holy Light and Cure answer emergencies. This answers
-- attrition -- the long grind where the party is winning but everybody is at half -- and it answers it
-- better than an emergency spell does, at the price of being useless in an emergency.
--
-- IT DOES NOT PICK SIDES, and cast at a foe the arithmetic inverts: the burn lands now, the mending
-- arrives later, and if the party finishes them in between the priest has simply dealt damage. That is
-- a legitimate (if graceless) use, and the Cathedral would prefer you did not call it that.
--
-- The scour is `holy`-tagged rather than `fire`, so it is not doused by rain, does not spread into
-- forest, and reads against holy resist -- which matters against the demon roster, where this is
-- suddenly one of the better opening moves in the game.
--
-- ADJACENCY: a `staff` beside it, like Not Yet -- the field-triage half of the shelf rather than the
-- ceremonial half, and reachable by a Monk.
return {
    name = "Scouring Mercy",
    description = "Sears one body, then mends it for considerably more over the following turns.",
    flavor = "It is a cleansing. The Cathedral is quite firm that the screaming is incidental to it.",
    sprite = "assets/items/ability_scouring_mercy.png",
    type = "ability",
    tags = { "holy", "magical" },
    class = "priest",
    price = 280,
    repRank = 2,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 11 },
        damage = { 6, 6, 7, 8, 8, 9, 10, 10, 11, 12, 12 },
        requiresAdjacent = { tag = "staff" },
        effect = function(fx)
            local body = fx.unitAt(fx.tx, fx.ty)
            if not body then return end
            -- Burn first, mend second, and the order is the spell: a target the scour KILLS never gets
            -- the regeneration, which is what makes casting it on somebody at low health a genuine
            -- mistake rather than a slightly worse heal.
            fx.damage(body, { tags = { "holy", "magical" } })
            if not body.alive then return end
            -- Roughly twice the burn, paid across the clock. `magnitude` on a regen is per-turn (see
            -- ctx.accrue in models/status.lua), so this is authored as the readable per-turn rate the
            -- tooltip quotes rather than as a total anybody has to divide.
            fx.applyStatus(body, "status_regen", {
                magnitude = 5 + fx.level,
                duration = 15 + fx.level,
            })
        end,
    },
}
