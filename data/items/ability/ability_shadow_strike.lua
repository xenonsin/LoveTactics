-- Shadow Strike: dart in, cut an adjacent foe, and melt back to where the turn began. The strike lands
-- first, then the caster teleports to the tile it stood on when its turn opened (combat.turn.startX/Y,
-- recorded by Combat.startTurn) -- so a rogue can move up, hit, and retreat to safety in a single
-- action. If it never moved this turn, there is nowhere to snap back to and the blow simply lands in
-- place. Contrast Shadow Step (blink TO a foe): this blinks AWAY after striking. Scales with attack.
return {
    name = "Shadow Strike",
    description = "Strike an adjacent foe, then blink back to where your turn began.",
    sprite = "assets/items/ability_shadow_strike.png",
    type = "ability",
    tags = { "guile", "physical" },
    class = "rogue",
    price = 300,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 7 },
        damage = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 },
        effect = function(fx)
            fx.damage(fx.target)
            -- Snap back to the turn's origin tile, if we moved off it. That tile is empty -- no one
            -- else acts during our turn -- so the return can't collide; springing whatever waits there
            -- (a trap we already crossed) is the cost of retreating along the way we came.
            local turn = fx.combat.turn
            if turn and turn.startX and (turn.startX ~= fx.user.x or turn.startY ~= fx.user.y) then
                fx.teleportUser(turn.startX, turn.startY)
            end
        end,
    },
}
