-- SPOKEN: TIME IS -- the Brazen Head's first utterance (data/characters/character_brazen_head.lua; "Envy's
-- Bestiary", 2026-10-03, slice C). A wind-up, broken by a shove like every channel; when it lands, every body on
-- the head's side is Hasted.
--
-- Usable only when it is the utterance the head is due (models/envy_seat.lua). Named "Spoken: ..." so the head's
-- words and the two drops that carry them (Time Was, Time Is Past) are never read as the same piece.
local function due(unit, item)
    if require("models.envy_seat").dueUtterance(unit, item) then return true end
    return false, "Not this utterance yet"
end

return {
    name = "Spoken: Time Is",
    description = "Channeled: every ally is Hasted.",
    flavor = "The first thing it says is true. It is only ever true for a moment.",
    sprite = "assets/items/ability_time_is_spoken.png",
    type = "ability",
    class = "creature",
    tags = { "magical" },
    bound = true,
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        windup = 5,
        speed = 4,
        usable = due,
        effect = function(fx)
            for _, u in ipairs(fx.combat.units or {}) do
                if u.alive and u.side == fx.user.side then fx.applyStatus(u, "status_hasted") end
            end
        end,
    },
}
