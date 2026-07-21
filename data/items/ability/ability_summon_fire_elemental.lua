-- Bind a fire elemental to the field. The mage's counterpart to Summon Wolf: the same reservation
-- bargain (a quarter of maximum mana, spent on the cast and locked away for as long as the elemental
-- stands), placed at arm's length rather than adjacent, and scaling its magicDamage rather than its bite.
-- See data/items/ability/ability_summon_wolf.lua for how `reserve` and `scaling` work -- including the
-- one-at-a-time rule: the binding cannot be renewed while the elemental it made still stands.
--
-- Where the wolf differs: this one is BOUND, not called, and a binding lapses. `duration` gives the
-- elemental 24 ticks (roughly four rounds) before it fades of its own accord -- which also returns the
-- reserved mana and frees the ability. So the mage's summon is a burst of pressure on a timer, while
-- the archer's wolf is a permanent body that only mana scarcity limits. Cast it early and it will be
-- gone by the endgame; hold it and you are down a quarter of your mana until you spend it.
return {
    name = "Summon Fire Elemental",
    description = "Binds a fire elemental for a time. One at a time; reserves a quarter of your max mana.",
    flavor = "A binding lapses. The Arcanum finds that reassuring; the elemental does not.",
    sprite = "assets/items/ability_summon_fire_elemental.png",
    type = "ability",
    tags = { "summon", "fire" },
    activeAbility = {
        target = "tile",
        range = 2,
        speed = 6,
        channel = 4, -- the binding is now WOUND UP: four ticks of incantation before the elemental forms
        reserve = { stat = "mana", percent = 0.25 },
        effect = function(fx)
            local elem = fx.summon("character_fire_elemental", fx.tx, fx.ty, {
                scaling = { health = 1, magicDamage = 0.5 },
                amount = 12 + fx.level, -- base 12, +1 per upgrade level
                duration = 24, -- ticks; the binding lapses and the elemental fades
            })
            -- Capstone (forged to +10): the elemental erupts into being like a Fireball landing. Foes in
            -- the 3x3 around it are scorched (magicDamage-scaled, fire-tagged), and the ground is left
            -- ablaze -- a Fire hazard on every tile but the elemental's own, so its own body doesn't stand
            -- in the flames. Allies and the just-summoned elemental take no damage from the burst.
            if fx.level >= 10 then
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        local cx, cy = fx.tx + dx, fx.ty + dy
                        local u = fx.unitAt(cx, cy)
                        if u and u.alive and u ~= elem and u.side ~= fx.user.side then
                            -- "fire" (item tag) + "magical" (routes off the elemental's magicDamage),
                            -- exactly like a Fireball hit.
                            fx.damage(u, { amount = 16, tags = { "fire", "magical" } })
                        end
                        if not (cx == fx.tx and cy == fx.ty) then
                            fx.placeHazard(cx, cy, "hazard_fire")
                        end
                    end
                end
            end
        end,
    },
}
