-- Shadow Step: slip through the dark to a foe's side and cut it. The caster blinks to an open tile
-- beside the target (Combat.openTileNear, springing whatever waits there) and strikes. If the target
-- is hemmed in with no open neighbour, the strike still lands from where the caster stood.
return {
    name = "Shadow Step",
    description = "Blink to a foe's side and strike it.",
    sprite = "assets/items/ability_shadow_step.png",
    type = "ability",
    tags = { "guile", "physical" },
    class = "rogue",
    price = 260,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = { 6, 7, 8, 8, 9, 10, 11, 11, 12, 13, 14 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local x, y = fx.openTileNear(t.x, t.y)
            if x then fx.teleportUser(x, y) end
            fx.damage(t)
        end,
    },
}
