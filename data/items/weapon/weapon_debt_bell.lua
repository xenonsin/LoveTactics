-- A mace, so it shoves (docs/weapons.md). Its extra is what the landing costs everyone else: wherever the
-- shoved body comes to rest, every unit adjacent to that tile takes the impact too.
--
-- Quest-only: `class` with no `price`.
--
-- The family already prices a collision -- shove someone into a wall and both parties feel it. This turns
-- that from a two-body event into an area one, and it does it at a tile the WIELDER chose by aiming the
-- shove. So the mace stops being a displacement weapon that happens to hurt and becomes a delivery
-- system: the body is the ordnance, and where you put it decides who pays.
--
-- It is the only area damage on the knight's shelf that does not come from a hazard, and it reaches
-- across the board in a way nothing else knight-side does -- the blast lands two tiles away, at the end
-- of the shove, not around the wielder.
--
-- The cost is that it needs a crowd at the far end and there is frequently nobody there. Against a
-- scattered line it is an iron mace with a worse damage curve.
return {
    name = "The Debt-Bell",
    description = "Drives the target back two tiles -- and everything standing around where they land shares the impact.",
    flavor = "The Undercroft's phrase, borrowed by the Bastion's armourers without permission: it is not settled until everyone has paid.",
    sprite = "assets/items/debt_bell.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "melee" },
    class = "knight",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        -- Under an iron mace's: the splash is the rest of it.
        damage = { 6, 6, 7, 8, 8, 9, 10, 10, 11, 12, 13 },
        effect = function(fx)
            local t = fx.target
            fx.damage(t, { knockback = { distance = 2, amount = fx.amount } })
            if not t then return end
            -- Read the landing tile AFTER the shove has resolved -- that is the whole point, and reading
            -- it before would blast the tile the victim was standing on rather than the one it was put
            -- on. Half the swing to the neighbours: they were not hit, they were leant on.
            local share = math.max(1, math.floor((fx.amount or 0) / 2))
            for _, u in ipairs(fx.unitsNear(t.x, t.y, 1)) do
                -- Everyone but the body that was actually thrown -- it has already paid in full -- and
                -- not the wielder, who is holding the handle. Unsided otherwise: a debt is a debt.
                if u ~= t and u ~= fx.user and u.alive then
                    fx.damage(u, { amount = share })
                end
            end
        end,
    },
}
