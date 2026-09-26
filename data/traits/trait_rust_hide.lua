-- RUST HIDE: any weapon that strikes the bearer in melee rusts (status_tarnished) -- 2 less damage with
-- that weapon for the fight, stacking to -6. The Rust Mite's own hide (utility_rust_hide) and the
-- company's Rustcoat, reviewed 2026-09-25 ("The Coin-Eaters"): "weapons that hit it rust".
--
-- WHICH WEAPON rides the blow as `ctx.blow` (Combat.dealDamage stamps it), so the rust lands on the blade
-- that struck and nowhere else. A spell, an arrow, a fist, or an ability that is not a weapon rusts
-- nothing. `notAReaction`: a stunned mite is still made of rust.
local Status = require("models.status")

local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do if t == want then return true end end
    return false
end

return {
    name = "Rust Hide",
    description = "Any weapon that strikes it in melee is Tarnished.",
    notAReaction = true,
    onDamaged = function(ctx)
        local attacker, blow = ctx.attacker, ctx.blow
        if not (attacker and attacker.alive and blow and blow.type == "weapon") then return end
        if not hasTag(ctx.tags, "melee") and not hasTag(blow.tags, "melee") then return end
        local s = Status.get(attacker, "status_tarnished")
        if not s then s = Status.apply(ctx.combat, attacker, "status_tarnished", { magnitude = 0 }) end
        if not s then return end
        s.rust = s.rust or {}
        local cap = s.def.maxPerWeapon or 3
        if (s.rust[blow] or 0) >= cap then return end
        s.rust[blow] = (s.rust[blow] or 0) + 1
        local total = 0
        for _, n in pairs(s.rust) do total = total + n end
        s.magnitude = total
        ctx.log("action", string.format("%s's %s rusts.", (attacker.char and attacker.char.name) or "It",
            blow.name or "weapon"), attacker)
    end,
}
