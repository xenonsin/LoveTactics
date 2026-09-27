-- BOILING BLOOD: the Hemomancer's second spell, and its drop (Wrath's vampires, round 2). Bleed does NOT stack --
-- one wound, 3 raw a tile moved -- so the round-1 "x6 stacks" pitch was a false premise, and Keno chose to BURST the
-- one wound instead: target a bleeding foe within 4, END its Bleed, and deal 5 x the Bleed's magnitude as fire.
-- 15 against an ordinary wound; 25 against a Kingsblood one (magnitude 5). Raw, because the wound is already open.
local PER_POINT = 5

local function bleeding(_, other)
    return other ~= nil and require("models.status").has(other, "status_bleed")
end

return {
    name = "Boiling Blood",
    description = "End a bleeding foe's Bleed and deal 5 times its magnitude as fire damage.",
    flavor = "The wound hisses, and the steam that comes out of it is red.",
    sprite = "assets/items/ability_boiling_blood.png",
    type = "ability",
    tags = { "fire", "blood", "magical" },
    class = "mage",
    unlockLevel = 8,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        onlyAt = bleeding,
        range = 4,
        speed = 4,
        cost = { stat = "mana", amount = 10 },
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            local target = fx.target
            if not (target and target.alive) then return end
            local st = require("models.status").get(target, "status_bleed")
            if not st then return end
            local burst = PER_POINT * (st.magnitude or 3)
            fx.clearStatus(target, "status_bleed")
            fx.flatDamage(target, burst, { "fire", "magical" })
        end,
    },
}
