-- FEED: a vampire drinks from its thrall (Wrath's vampires, 2026-09-26). Aimed at an adjacent Blood-Ghoul only
-- (`onlyAt`, the thrall's flag): the ghoul takes the wound, and the vampire drinks it -- its Thirst resets and it
-- heals, as a feeding heal (fx.feed, models/thirst.lua). The drink is 40% of the thrall's max health.
--
-- The planner does not reach it through a rule: AI.preempt asks models/thirst.lua, which casts it at Thirst 2
-- when a thrall stands beside the vampire.
local SHARE = 0.40

local function isThrall(_, other)
    return other ~= nil and require("models.trait").flag(other, "thrall") ~= nil
end

return {
    name = "Feed",
    description = "Drink from an adjacent Blood-Ghoul. It takes the wound; your Thirst resets and you heal.",
    flavor = "The ghoul tilts its head aside before it is asked.",
    sprite = "assets/items/ability_feed.png",
    type = "ability",
    tags = { "natural", "blood" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "ally",
        excludeSelf = true,
        onlyAt = isThrall,
        range = 1,
        speed = 3,
        support = true,
        effect = function(fx)
            local target, user = fx.target, fx.user
            if not (target and target.alive and user) or not isThrall(user, target) then return end
            local drink = math.max(1, math.floor(target.char.stats.health.max * SHARE + 0.5))
            local drawn = fx.flatDamage(target, drink, { "bleed" })
            fx.feed(user, drawn)
        end,
    },
}
