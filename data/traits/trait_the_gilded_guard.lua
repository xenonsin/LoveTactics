-- THE GILDED GUARD: the Gilded King's men open every fight Gilded (2026-09-26, the Gilded King: "His guard
-- are also all gilded"). The dwarves he hired to dig his vault, and kept -- and everything he kept, he
-- touched. At the bell every other body on his side takes the Gilded status (data/status/status_gilded.lua):
-- +3 Defense, slower, for its usual four turns.
--
-- ON THE KING, NOT ON THE GUARD, which is the reading of the note that needs no second skeleton. A dead
-- dwarf with a gilded variant would be a body of its own for a status, and the one on Vesh's floor would
-- have to stay ungilded. So the King gilds whoever stands with him, and the fight the review approved is
-- the fight that seats him. It is the bell only: a body that arrives later arrives plain.
--
-- AND IT PAYS: Gilded pays its bounty into the spoils when a gilded body falls on his side, so a guard cut
-- down inside the four turns is worth twenty gold to the company.
local Status = require("models.status")

return {
    name = "The Gilded Guard",
    description = "At the start of a fight, every ally opens Gilded.",
    onCombatStart = function(ctx)
        local combat, king = ctx.combat, ctx.unit
        if not (combat and king) then return end
        for _, u in ipairs(combat.units or {}) do
            if u ~= king and u.alive and u.side == king.side then
                Status.apply(combat, u, "status_gilded", { applier = king })
            end
        end
    end,
}
