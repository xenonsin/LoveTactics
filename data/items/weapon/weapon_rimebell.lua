-- A mace, so it shoves (docs/weapons.md). Its extra is that the shove leaves a wake: every tile the body
-- was dragged across freezes over (hazard_rimeguard), so enemies standing in it are slowed to a crawl.
--
-- Quest-only: `class` with no `price`.
--
-- Three ways of holding ground exist in this game and docs/weapons.md lays them out -- a banner stays, a
-- trail is left behind, incense walks. This is a fourth reading and it is the only one that paints with
-- somebody ELSE's body: the wielder does not walk the line, the victim does, involuntarily, and the ice
-- is drawn wherever the mace decided to send them.
--
-- Which makes it the one board-control weapon whose shape the player draws at the moment of use rather
-- than by walking. Shove along a corridor and you have iced the corridor. Shove across the enemy's
-- approach and you have iced the approach.
--
-- Note the ground is unsided as ground generally is: rimeguard slows enemies specifically
-- (data/hazards/hazard_rimeguard.lua), so this is one of the few zones that is safe to leave in front of
-- your own line -- which is why the mace can afford to keep a full two tiles of shove.
return {
    name = "Rimebell",
    description = "Drives the target back two tiles, freezing over every tile they are dragged across.",
    flavor = "The head is always cold. The armourer who forged it is no longer with the Bastion, and no longer with anyone.",
    sprite = "assets/items/rimebell.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "ice", "melee" },
    class = "knight",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        damage = { 6, 7, 7, 8, 9, 9, 10, 11, 12, 12, 13 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            -- Where it started, so the wake can be drawn between there and wherever it stops.
            local fromX, fromY = t.x, t.y
            fx.damage(t, { knockback = { distance = 2, amount = fx.amount } })

            -- The travelled cells: the straight run from origin to landing, endpoints included. Reading
            -- the ACTUAL travel rather than the declared two tiles is what keeps the ice honest when a
            -- wall cuts the shove short -- a body that moved one tile ices one tile.
            local dx = (t.x > fromX and 1) or (t.x < fromX and -1) or 0
            local dy = (t.y > fromY and 1) or (t.y < fromY and -1) or 0
            local steps = math.max(math.abs(t.x - fromX), math.abs(t.y - fromY))
            for i = 0, steps do
                fx.placeHazard(fromX + dx * i, fromY + dy * i, "hazard_rimeguard",
                    { duration = 8 + fx.level })
            end
        end,
    },
}
