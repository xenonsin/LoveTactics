-- VIRTUE'S AEGIS: the Virtue's whole work, and its drop (reviewed 2026-09-30, "Pride's Bestiary").
--
-- It lays Aegis -- the priest's own defensive benediction (status_aegis, "Warded") -- on the ally that took the most
-- damage last round, the bearer included. It is not aimed: the Virtue does not choose who to save, the wound does.
-- "Last round" is the bearer's own (trait_keeping_watch banks every body's damage at the end of each of its turns),
-- and the ally hurt most since then is the one warded. With nobody hurt there is nothing to answer, and the cast
-- refuses rather than spending a turn on nothing.
--
-- On the angels it closes the gap the company would otherwise open: you cannot lay a debuff on the choir, so you
-- focus a body down -- and the body you were focusing is the one that comes up Warded.
--
-- `unstocked`: a trophy, seen on the priest's rack and never sold (docs/drops.md).

-- The ally of `unit`'s side hurt most since the end of `unit`'s last turn, and by how much; nil when nobody was.
local function wounded(unit)
    local Combat = require("models.combat")
    local combat = unit and unit.combat
    if not combat then return nil end
    local seen = unit.watchSeen or {}
    local best, most
    for _, ally in ipairs(combat.units or {}) do
        if ally.alive and ally.side == unit.side and not Combat.isOffTile(ally) then
            local taken = Combat.tallyCount(ally, "damageTaken") - (seen[ally] or 0)
            if taken > 0 and (not most or taken > most) then best, most = ally, taken end
        end
    end
    return best, most
end

return {
    name = "Virtue's Aegis",
    description = "Ward the ally that took the most damage last round.",
    flavor = "It does not ask who deserved the blow. It asks who took it, and stands there instead.",
    sprite = "assets/items/ability_virtues_aegis.png",
    type = "ability",
    tags = { "holy", "protective" },
    class = "priest",
    unlockLevel = 8,
    unstocked = true,
    traits = { "trait_keeping_watch" },
    activeAbility = {
        target = "self",
        support = true,
        range = 0,
        speed = 3,
        cooldown = 5,
        cost = { stat = "mana", amount = 8 },
        usable = function(unit)
            if wounded(unit) then return true end
            return false, "Nobody has been hurt since your last turn"
        end,
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            local ally = wounded(fx.user)
            if ally then fx.applyStatus(ally, "status_aegis") end
        end,
    },
}
