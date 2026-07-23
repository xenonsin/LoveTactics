-- A spear, so it skewers a line (docs/weapons.md). Its extra is on the FAR tile: whatever stands in the
-- second rank is marked for an hour (status_knell), and when the count runs out, it dies.
--
-- Quest-only: `class` with no `price`.
--
-- What it sells is a kill that is not a number. Every other weapon in this game asks "is my damage bigger
-- than their health" -- this one asks "can I keep them alive-and-marked for four turns", which the enemy
-- answers with a cure and the player answers by threatening whoever holds the cure. It converts a fight
-- about arithmetic into a fight about tempo, and it does it to the body in the SECOND rank: the officer,
-- the caster, the one standing behind the wall precisely because nothing was supposed to reach him.
--
-- Only the far tile, which is the whole discipline of the weapon. The near body is just skewered. A pike
-- that knelled everything it touched would be an execution button; this one has to be aimed THROUGH
-- somebody, so the enemy's own front rank is what decides whether the mark can be placed at all.
--
-- Knell is deliberately not `resistible` (see its header: the resist system buys duration, and duration
-- is the wrong axis for a thing whose whole design is a fixed countdown) -- so what answers it is a
-- cleanse, and cleansing is a turn the enemy healer spends not healing. That is the real payoff even
-- when the mark never comes due.
return {
    name = "Knell-Point",
    description = "Skewers the two tiles ahead, and marks whatever stands in the second rank for death.",
    flavor = "The bell is rung when the thrust lands. What it is counting down to has already been decided.",
    sprite = "assets/items/knell_point.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "melee" },
    hands = 2,
    class = "knight",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        -- Well under an iron spear's. A weapon that also kills outright must not also hit hard.
        damage = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            -- The far tile is the aimed cell continued one step along the thrust's own vector -- the
            -- same geometry weapon_second_rank reads, pointed forward instead of back.
            local dx = fx.tx - fx.user.x
            local dy = fx.ty - fx.user.y
            local farX, farY = fx.tx + dx, fx.ty + dy

            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
                if u.alive and u.x == farX and u.y == farY then
                    fx.applyStatus(u, "status_knell")
                    fx.log("action", string.format("A bell is rung for %s.",
                        (u.char and u.char.name) or "the second rank"))
                end
            end
        end,
    },
}
