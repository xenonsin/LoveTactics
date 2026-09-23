-- DRAGLINE: the line a spider pays out behind it, rebuilt as a hunter's leap. Aimed at a foe that is
-- Rooted or Marked -- held, or painted -- the bearer arrives on open ground beside them. The Lodge's
-- setup statuses become a road: whatever caught the quarry is what carries you to it. Off the Giant
-- Spider; a trophy.
return {
    name = "Dragline",
    description = "Leap to open ground beside a Rooted or Marked foe.",
    flavor = "It is not a rope. It is a direction, and you are on the end of it.",
    sprite = "assets/items/ability_dragline.png",
    type = "ability",
    tags = { "silk", "movement" },
    class = "skirmisher",
    unlockLevel = 4,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 6,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            if not (fx.hasStatus(t, "status_root") or fx.hasStatus(t, "status_mark")) then
                fx.log("The line finds nothing to hold.")
                return
            end
            local x, y = fx.openTileNear(t.x, t.y)
            if x then fx.teleportUser(x, y, { glide = true }) end
        end,
    },
}
