-- THE WALTZ: the Blood Countess's drop (Wrath's vampires, round 3, approved). Trade places with a foe within 3 --
-- and a BLEEDING one takes its Bleed for every tile of the swap, the same as if it had walked them. A swap
-- otherwise bleeds nobody (Combat.swapUnits crosses no ground), so this is the one swap that does.
--
-- The tiles are the gap between the two of you before the swap (Combat.unitGap). Each is one tick of the wound
-- the foe already carries, at that wound's own magnitude and with its own opener, so a vampire that cut it still
-- drinks and a basin standing anywhere still fills.
local function bleedOnce(combat, target)
    local st = require("models.status").get(target, "status_bleed")
    if not (st and target.alive) then return 0 end
    return require("models.combat").dealFlatDamage(combat, target, st.magnitude or 3, { "bleed" }, "Bleed", nil,
        { raw = true, bledBy = st.opener })
end

return {
    name = "The Waltz",
    description = "Trade places with a foe within 3. A bleeding foe takes its Bleed for every tile of the swap.",
    flavor = "One, two, three, and you are where she was, and she is smiling at the blood on your sleeve.",
    sprite = "assets/items/ability_the_waltz.png",
    type = "ability",
    tags = { "utility", "blood" },
    class = "duelist",
    unlockLevel = 8,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        speed = 3,
        cooldown = 10, -- two turns
        cost = { stat = "stamina", amount = 8 },
        effect = function(fx)
            local target = fx.target
            if not (target and target.alive) then return end
            local Combat = require("models.combat")
            local tiles = Combat.unitGap(fx.user, target)
            local tx, ty = target.x, target.y
            if not fx.swap(target) then return end
            -- Only a swap that really happened bleeds: a preview's stand-in reports success and moves nobody.
            if target.x == tx and target.y == ty then return end
            for _ = 1, tiles do
                if not target.alive then break end
                bleedOnce(fx.combat, target)
            end
        end,
    },
}
