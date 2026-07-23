-- A spear, so it skewers a line (docs/weapons.md). Its extra is that the line gets LONGER when somebody
-- is standing behind you: with an ally directly at the wielder's back, the thrust reaches a third tile.
--
-- Quest-only: `class` with no `price`.
--
-- This is the pike drill written as a weapon, and it is the only item in the game that rewards the
-- formation the Bastion actually teaches. Every other positional bonus here reads sideways -- `covers`
-- pays your neighbours, a banner pays a square, Formation Fighter reads adjacency generally. This one
-- reads the tile BEHIND, which is the one direction a player never thinks about, and it turns "get out
-- of the spearman's way" into "get in line behind the spearman."
--
-- The reach is checked at swing time against the live board, so it is a thing the player arranges and
-- can lose: the ally steps off to flank, and the pike is an ordinary iron spear again that turn.
--
-- On the footprint: the declared `aoe` stays at the family's length 2, and the third tile is struck in
-- the effect. That direction is safe -- the aim preview under-promises reach and never over-promises
-- damage. Declaring length 3 and narrowing it would show the player a third tile the swing usually
-- cannot reach, which is the lie worth avoiding.
return {
    name = "Reach of the Second Rank",
    description = "Skewers the two tiles ahead -- three, while an ally stands directly at your back.",
    flavor = "A pike is not long because of the pole. It is long because of the man behind you, who is also holding one.",
    sprite = "assets/items/second_rank.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "melee" },
    hands = 2,
    class = "knight",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 9 },
        damage = { 5, 6, 6, 7, 8, 8, 9, 10, 10, 11, 12 },
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end

            -- The thrust runs from the wielder through the aimed cell; "behind" is that same vector
            -- reversed, and "the third tile" is it continued one step further. One direction, read twice.
            local dx = fx.tx - fx.user.x
            local dy = fx.ty - fx.user.y
            if dx == 0 and dy == 0 then return end
            local backer = fx.unitAt(fx.user.x - dx, fx.user.y - dy)
            if not (backer and backer.alive and backer.side == fx.user.side) then return end

            local third = fx.unitAt(fx.tx + dx, fx.ty + dy)
            if third then
                fx.damage(third)
                fx.log("action", string.format("%s thrusts from the second rank.",
                    (fx.user.char and fx.user.char.name) or "Unit"))
            end
        end,
    },
}
