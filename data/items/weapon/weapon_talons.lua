-- A hawk's natural weapon: the light end of the beast shelf, softer even than a wolf's Fangs
-- (data/items/weapon/weapon_fangs.lua), because a hawk is a spotter, not a killer -- see
-- data/traits/trait_falconers_hawk.lua. `natural`, `noSteal`, sold by nobody: a creature's body is not
-- loot, and no vendor stocks it (docs/classes.md, "Monk, and why there is no fist weapon").
--
-- The rake is a STOOP: the bird drops on the quarry and is back on its perch before the arm comes up.
-- Mechanically that is Shadow Strike's return-to-origin blink (data/items/ability/ability_shadow_strike.lua)
-- -- strike first, then teleport to the tile the turn opened on (combat.turn.startX/Y, pinned by
-- Combat.startTurn). It is the one thing a 14-health bird can be given that makes its 7 movement worth
-- spending: it can cross the field, pick at something, and not be standing next to it when the field
-- answers. Contrast the wolf's Fangs, which give a single tile of ground (fx.retreat) -- a wolf backs
-- off, a hawk leaves. If the hawk never moved this turn there is nowhere to snap back to and the rake
-- simply lands in place.
return {
    name = "Talons",
    description = "Rakes an adjacent foe, then returns to where the turn began.",
    flavor = "Enough to draw blood and break a line of sight. It is gone before the blood is.",
    sprite = "assets/chars/hawk.png",
    type = "weapon",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true, -- a hawk's talons cannot be lifted off it
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3, -- fast, matching a light quick strike
        cost = { stat = "stamina", amount = 4 },
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 }, -- softer than Fangs: the bird is not the threat
        effect = function(fx)
            fx.damage(fx.target)
            -- Back to the perch: the turn's origin tile, if the bird left it. That tile is empty --
            -- nothing else acts during our turn -- so the return cannot collide.
            local turn = fx.combat.turn
            if turn and turn.startX and (turn.startX ~= fx.user.x or turn.startY ~= fx.user.y) then
                fx.teleportUser(turn.startX, turn.startY)
            end
        end,
    },
}
