-- Dray's bound relic (Vanguard). He opens a line and does not walk through it himself.
--
-- BREAKER'S WEDGE IS THE ENGINE UNDER IT: with that charm carried, every knockback he inflicts also
-- Sunders, so this charge strips the whole lane rather than merely shoving it. That is the shelf
-- earning its keep -- the relic is a bigger version of a rule the player already bought, not a rule of
-- its own. Breaker's Harness stuns whatever it pins to a wall, and Stripped Plate turns their armour
-- into his.
--
-- SUNDER IS THE POINT AND IT IS RARE. Nineteen items cause knockback; five things in the whole catalog
-- apply Sundered. A vanguard's mechanic barely exists without the charm, which is why the relic is
-- written to reward carrying it rather than to duplicate it.
return {
    name = "The Wedge",
    description = "Drives down a lane, shoving and Sundering everything standing in it.",
    flavor = "He is not making a hole to walk through. He is making one for everybody behind him.",
    sprite = "assets/items/sig_the_wedge.png",
    type = "utility",
    tags = { "signature", "impact", "physical" },
    class = "knight",
    discipline = "vanguard",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1, -- aim the ADJACENT first tile: forced movement resolves on the dominant axis
        speed = 6,
        cost = { stat = "stamina", amount = 12 },
        description = "Shoves and Sunders everything down the lane ahead of you.",
        unlock = { event = "hitDealt", count = 3, text = "Land 3 blows" },
        effect = function(fx)
            -- Walk the lane out from the aimed tile, in the direction it points. Everything caught is
            -- driven back and left open; the Sunder rides the shove for a bearer carrying the Wedge
            -- charm, and is applied here too so the relic reads true on its own.
            local dx, dy = fx.tx - fx.user.x, fx.ty - fx.user.y
            if math.abs(dx) >= math.abs(dy) then dy = 0 else dx = 0 end
            dx = dx > 0 and 1 or (dx < 0 and -1 or 0)
            dy = dy > 0 and 1 or (dy < 0 and -1 or 0)
            for step = 1, 4 do
                local caught = fx.unitAt(fx.user.x + dx * step, fx.user.y + dy * step)
                if caught and caught.side ~= fx.user.side then
                    fx.damage(caught, { knockback = { distance = 2, amount = fx.amount } })
                    fx.applyStatus(caught, "status_sundered")
                end
            end
        end,
    },
    -- driving down a lane through bodies
    bonus = { damage = 2 },
}
