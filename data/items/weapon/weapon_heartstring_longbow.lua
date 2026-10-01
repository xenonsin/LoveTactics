-- THE HEARTSTRING LONGBOW: the Elf Longbow's bow, and its drop (data/characters/character_elf_longbow.lua).
-- Approved 2026-09-30 ("Pride's Bestiary"): DRAWN STANCE.
--
-- A longbow, so it is drawn before it looses (the family's contract, docs/weapons.md). Its extra is the stance:
-- drawn on a turn the archer had not moved, the shot cannot be avoided (`drawnStance`, Combat.drawnStance, read by
-- Combat.rollsToHit) and carries through to the body standing behind its target. The draw is judged when it is
-- made, not when the arrow leaves -- the channel carries the answer to the loosing.
local Curve = require("models.curve")

-- One step on from the target, straight back along the line from the archer: the dominant axis, or the diagonal
-- when the two are equal.
local function behind(user, tx, ty)
    local dx, dy = tx - user.x, ty - user.y
    local sx = dx > 0 and 1 or (dx < 0 and -1 or 0)
    local sy = dy > 0 and 1 or (dy < 0 and -1 or 0)
    if math.abs(dx) > math.abs(dy) then sy = 0 elseif math.abs(dy) > math.abs(dx) then sx = 0 end
    return tx + sx, ty + sy
end

return {
    name = "Heartstring Longbow",
    description = "Channeled. If you haven't moved this turn, your shot can't be avoided and carries through to the body behind.",
    flavor = "A white yew longbow strung with one pale cord that hums when it is drawn.",
    sprite = "assets/items/weapon_heartstring_longbow.png",
    type = "weapon",
    tags = { "longbow", "pierce", "physical", "ranged" },
    hands = 2,
    class = "hunter",
    unlockLevel = 13,
    unstocked = true,
    drawnStance = true,
    activeAbility = {
        target = "enemy",
        range = 5,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        windup = 2,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(20, 32), -- what its rung asks of a longbow (balance_spec); the stance is on top
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local bx, by = behind(fx.user, t.x, t.y)
            fx.damage(t)
            if fx.user.drawnShot then
                local back = fx.unitAt(bx, by)
                if back and back ~= fx.user and back.alive and back.side ~= fx.user.side then fx.damage(back) end
            end
        end,
    },
}
