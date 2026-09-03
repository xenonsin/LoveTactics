-- Hilde's bound relic (Warbrewer). She drinks her way through a fight, and this is the round where all
-- of it lands at once.
--
-- IT BANKS `consumed` RATHER THAN `cast`, and the distinction is the whole reason the tally exists: the
-- two agree only until she swings a weapon, and a warbrewer's signature has to count what she put away
-- rather than what she did. Four drinks is the gate, and Field Still -- which brews one into her grid
-- every turn -- means waiting is accumulating.
--
-- WHAT IT DOES is pour everything left in the grid at once and share it out. Round for the House
-- already puts her draughts on the party at half; this is that idea spent rather than sipped, and the
-- two Bandoliers are what make the drinking cost her nothing on the way here.
return {
    name = "Last Call",
    description = "Drinks every flask left in your grid at once, and the party gets a share.",
    flavor = "She has never once been the last one standing by accident.",
    sprite = "assets/items/sig_last_call.png",
    type = "utility",
    tags = { "signature", "alchemy" },
    class = "warbrewer",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "stamina", amount = 6 },
        aoe = { radius = 2, shape = "square" },
        description = "Empties your flasks at once, restoring your side around you.",
        unlock = { event = "consumed", count = 4, text = "Drink 4" },
        counter = function(unit)
            return unit and require("models.combat").tallyCount(unit, "consumed") or 0
        end,
        counterLabel = "Drunk",
        effect = function(fx)
            -- Counted, not consumed: emptying the grid is an item mutation the damage preview would
            -- have to replay, and a hover that drank her flasks would be a bug the player could see.
            -- The pour is measured by how much she is carrying instead, which reads the same way round.
            local flasks = 0
            for _, held in ipairs(fx.adjacentItems() or {}) do
                if held.type == "consumable" then flasks = flasks + 1 end
            end
            -- `fx.amount` is nil for an ability that authors no damage curve, and the tooltip's dry run
            -- reaches this line too -- so the floor is spelled out rather than assumed.
            local pour = (fx.amount or 0) + 8 + flasks * 5
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side == fx.user.side then fx.heal(u, pour) end
            end
            fx.applyStatus(fx.user, "status_empowered", { magnitude = 4 + flasks * 2 })
        end,
    },
    -- drinking everything at once and coming out of it upright
    bonus = { magicDefense = 1, luck = 1 },
}
