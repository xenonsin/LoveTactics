-- Shout: a battle-cry that yanks every nearby foe's attention onto the knight. Aim an adjacent tile;
-- every enemy in the diamond around it is Taunted (data/status/taunt.lua) -- while it lasts they must
-- come for the shouter with their default weapon and nothing else (Combat.planEnemyAction reads the
-- taunt's `.taunter`, stamped here). The knight's answer to Sloth: draw the blows onto the one built
-- to take them. Allies caught in the area are untouched -- only foes are provoked.
return {
    name = "Shout",
    description = "A war-cry that taunts nearby foes: they must attack you with their default weapon.",
    sprite = "assets/items/ability_shout.png",
    type = "ability",
    tags = { "impact" },
    class = "knight",
    price = 240,
    repRank = 2,
    activeAbility = {
        name = "Shout",
        target = "tile",       -- aim a nearby tile; the diamond around it is the shout's reach
        allowOccupied = true,
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        aoe = { shape = "diamond", radius = 1 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then
                    local st = fx.applyStatus(u, "taunt")
                    if st then st.taunter = fx.user end -- who the taunt drags them toward
                end
            end
        end,
    },
}
