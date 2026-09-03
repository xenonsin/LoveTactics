-- Dov's bound relic (Bulwark). He does not kill people. He closes doors.
--
-- DELIBERATELY NOT ROWAN'S VERB. The Sworn Aegis strikes and shoves the ring around it, and a bulwark
-- relic that did the same with a Halt bolted on would be the knight's signature spelled twice. This one
-- moves nobody -- it removes the ROUTE. A wall goes up across the rank he is facing and stays up, so
-- the shortest way to whatever he is standing in front of stops existing.
--
-- THE CENSUS IS FOUR FOES WITHIN TWO TILES: it opens when a crowd has gathered, which is exactly when
-- a door is worth shutting, and it closes again when they disperse. A bulwark nobody is converging on
-- has nothing to shut.
--
-- Walls are real board objects (models/wall.lua, laid through fx.placeWall), so everything already
-- knows what to do with them: pathing routes around, sight breaks on them, and the shelf's own Halting
-- Rank and Closed Ring punish whatever queues at the new bottleneck.
return {
    name = "Doorstone",
    description = "Raises a wall across three tiles, and Halts whoever it puts out of the way.",
    flavor = "A door is not a weapon. It is the argument you no longer have to have.",
    sprite = "assets/items/sig_doorstone.png",
    type = "utility",
    tags = { "signature", "impact" },
    class = "knight",
    discipline = "bulwark",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1, -- aim the tile the door is centred on; it spreads to either side of that
        speed = 6,
        cost = { stat = "stamina", amount = 14 },
        description = "Raises a wall across three tiles, Halting whoever it displaces.",
        unlock = {
            field = { of = "unit", side = "foe", within = 2, count = 4 },
            text = "4 foes within 2 tiles",
        },
        effect = function(fx)
            -- ACROSS the way in, never along it: the span runs perpendicular to the line from the
            -- caster. An exact diagonal falls back to the horizontal, the same tie-break the board's
            -- dominant-axis rule takes everywhere else.
            local dx, dy = fx.tx - fx.user.x, fx.ty - fx.user.y
            local sx, sy = 0, 1
            if math.abs(dy) >= math.abs(dx) then sx, sy = 1, 0 end
            for i = -1, 1 do
                local wx, wy = fx.tx + sx * i, fx.ty + sy * i
                local standing = fx.unitAt(wx, wy)
                if standing and standing.side ~= fx.user.side then
                    -- Somebody in the doorway is put out of it rather than built into it, and told to
                    -- stand still where they land. The wall then goes up behind them.
                    fx.knockback(standing, 1)
                    fx.applyStatus(standing, "status_halted")
                end
                fx.placeWall(wx, wy)
            end
        end,
    },
    -- it raises a wall; the wall is the item
    bonus = { defense = 3 },
}
