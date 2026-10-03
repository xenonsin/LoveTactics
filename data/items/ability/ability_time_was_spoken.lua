-- SPOKEN: TIME WAS -- the Brazen Head's second utterance (data/characters/character_brazen_head.lua; "Envy's
-- Bestiary", 2026-10-03, slice C). A wind-up; when it lands, every body on the head's side heals what it has lost
-- since the head last spoke, read off the ledger its organ keeps (models/envy_seat.lua). The answer is the gap
-- between the first and second utterances: burst the guards there, or shove the head and make it say it again.
local function due(unit, item)
    if require("models.envy_seat").dueUtterance(unit, item) then return true end
    return false, "Not this utterance yet"
end

return {
    name = "Spoken: Time Was",
    description = "Channeled: every ally heals what it lost since the last utterance.",
    flavor = "The second thing it says was true. It says it as though that were the same.",
    sprite = "assets/items/ability_time_was_spoken.png",
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
            local EnvySeat = require("models.envy_seat")
            for _, u in ipairs(fx.combat.units or {}) do
                if u.alive and u.side == fx.user.side then
                    local lost = EnvySeat.lostSince(fx.user, u)
                    if lost > 0 then fx.heal(u, lost) end
                end
            end
        end,
    },
}
