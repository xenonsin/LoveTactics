-- THE INSTANT-DRAW KATANA: the Oni Swordmaster's sword, and its drop. Approved 2026-09-26 ("The Oni of Wrath"),
-- after Reincarnated as a Slime's old master who draws and cuts in one motion.
--
-- A sword, so it answers a melee blow (trait_parry, the family's contract). Its trick is the wait: Wait becomes
-- Overwatch, and the first foe to step into reach is struck before it acts -- the existing overwatch, zone 1.
local Curve = require("models.curve")

return {
    name = "Instant-Draw Katana",
    description = "Strikes an adjacent foe and answers an adjacent melee blow. Replaces Wait with Overwatch.",
    flavor = "The sheath is the stance. By the time you see the blade it has already gone back.",
    sprite = "assets/items/weapon_instant_draw_katana.png",
    type = "weapon",
    tags = { "sword", "slash", "physical", "melee" },
    hands = 1,
    traits = { "trait_parry" },
    class = "duelist",
    unlockLevel = 8,
    unstocked = true,
    waitBehavior = { kind = "overwatch", speed = 10, stamina = 4, zone = 1 },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(10, 22),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
