-- SPOKEN: TIME IS PAST -- the Brazen Head's last utterance (data/characters/character_brazen_head.lua; "Envy's
-- Bestiary", 2026-10-03, slice C). A wind-up; when it lands the head shatters (fx.expendSelf), and every foe within
-- 3 is Stunned. A shove breaks it like the other two.
local function due(unit, item)
    if require("models.envy_seat").dueUtterance(unit, item) then return true end
    return false, "Not this utterance yet"
end

return {
    name = "Spoken: Time Is Past",
    description = "Channeled: shatters itself, and every foe within 3 is Stunned.",
    flavor = "The third thing it says is the last thing anybody hears it say.",
    sprite = "assets/items/ability_time_is_past_spoken.png",
    type = "ability",
    class = "creature",
    tags = { "magical" },
    bound = true,
    noSteal = true,
    activeAbility = {
        target = "self",
        support = false,
        range = 0,
        windup = 5,
        speed = 4,
        aoe = { shape = "diamond", radius = 3 },
        usable = due,
        effect = function(fx)
            local user = fx.user
            fx.burst(user.x, user.y, { "magical" })
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= user and u.alive and u.side ~= user.side then fx.applyStatus(u, "status_stun") end
            end
            fx.expendSelf(string.format("%s shatters.", (user.char and user.char.name) or "The head"))
        end,
    },
}
