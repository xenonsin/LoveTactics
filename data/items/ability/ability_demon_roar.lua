-- The Demon Champion's second-stage move (armed at 66% health by data/traits/trait_boss_phases.lua,
-- which raises status_roaring; the Champion's AI winds this up only while that marker stands). A
-- telegraphed bellow: it winds up over two ticks and, if it resolves, calls two Bomblets to the
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
local Curve = require("models.curve")

return {
    name = "Demon's Roar",
    description = "Channeled: summons Bomblets and quickens the champion.",
    flavor = "The horde answers the loudest throat.",
    sprite = "assets/items/ability_meteor_storm.png", -- placeholder until its own art exists
    type = "ability",
    class = "creature",
    dropTier = 8,
    tags = { "summon" },
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        speed = 6,
        -- The two-tick tell: the window a Stun or a shove has to deny the call.
        --
        -- It was THREE, and three was a threat that never arrived. The Roar is armed at 66% health, and
        -- the fight it is armed in runs about four rounds -- so a channel opened on round two and paid
        -- out on round five resolved after the Champion was already dead, and the Bomblets the stage is
        -- made of never reached the board at all. A denial lesson needs something to deny. Two ticks
        -- still leaves a full turn to answer it in, which is the window Jolt and the Sworn Aegis were
        -- handed over for.
        windup = 2,
        -- Paid in MANA, like the Cleave: the Champion's body (its claws, the Sigil's riposte, a Heave)
        -- is billed to stamina and its WILL to mana, which is the contract every demon on the board
        -- keeps (data/characters/character_demon_grunt.lua). 12 of a 60-mana pool, and mana does not
        -- regenerate (Combat.regenerate) -- so the Roar is a thing the fight has a countable number of,
        -- and a Drain Mana thrown at the Champion (8 at base, 20 forged) is most of one taken away.
        cost = { stat = "mana", amount = 12 },
        aoe = { radius = 1, shape = "square" },
        damage = Curve.ramp(6, 16), -- a real bruise, so the AI values winding it up
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
