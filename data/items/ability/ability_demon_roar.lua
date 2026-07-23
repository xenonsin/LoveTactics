-- The Demon Champion's second-stage move (armed at 66% health by data/traits/trait_boss_phases.lua,
-- which raises status_roaring; the Champion's AI winds this up only while that marker stands). A
-- telegraphed bellow: it winds up over three ticks and, if it resolves, calls two Bomblets to the
-- Champion's side and quickens it. INTERRUPT it -- a Stun (Jolt / Power Strike) or a shove (a mace, the
-- Sworn Aegis) breaks any channel (Combat.interruptChannel), and the pending call is wasted: no
-- Bomblets. That denial is the whole point of the stage.
--
-- It aims an adjacent tile (range 1, allowOccupied) so it is ALWAYS a legal cast for the AI, and it
-- carries real damage -- the AI only takes a candidate whose outcome > 0, and a pure-summon cast scores
-- nothing and would never be wound up. The bellow bruises and shoves the adjacent ring a tile back
-- (a menace, folded into the blow), then the wind-up pays off: two Bomblets on open ground beside it,
-- SUMMONED and sustained by it, so they vanish when it falls and the assassinate win stays honest
-- (a summoned Volatile that is dismissed does not burst -- data/traits/trait_volatile.lua).
return {
    name = "Demon's Roar",
    description = "Winds up a bellow that calls Bomblets and quickens the champion. Break its concentration.",
    flavor = "The horde answers the loudest throat.",
    sprite = "assets/items/ability_meteor_storm.png", -- placeholder until its own art exists
    type = "ability",
    tags = { "summon" },
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        speed = 6,
        channel = 3, -- the three-tick tell: the window a Stun or a shove has to deny the call
        cost = { stat = "stamina", amount = 6 },
        aoe = { radius = 1, shape = "square" },
        damage = { 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11 }, -- a real bruise, so the AI values winding it up
        effect = function(fx)
            -- The bellow: bruise + shove the adjacent ring one tile back (friend and self spared).
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then
                    fx.damage(u, { knockback = { distance = 1, amount = fx.amount } })
                end
            end
            -- The call it was winding up: two Bomblets on open ground beside it, sustained by it.
            for _ = 1, 2 do
                local x, y = fx.openTileNear(fx.user.x, fx.user.y)
                if x then fx.summon("character_demon_bomblet", x, y) end
            end
            -- ...and it steels itself for having weathered the interrupt window.
            fx.applyStatus(fx.user, "status_hasted")
        end,
    },
}
