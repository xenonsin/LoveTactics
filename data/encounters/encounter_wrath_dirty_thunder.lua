-- DIRTY THUNDER: a Blaze and an Arc, and the storm they make (models/storm.lua; character_thunderhead). A spare elite
-- of Wrath's seat, reviewed 2026-09-27/28 ("Fire, Lightning, and Dirty Thunder").
--
-- The first half of the fight is keeping the two apart: end any turn with them side by side and they fuse into the
-- Thunderhead. Bring it to half and it tears back into the two; let them meet again and the storm comes back to
-- fight to the end. While it stands every fire conducts its lightning, so the Blaze's Wildfire is the storm's reach.
--
-- A CAST OF TWO BY REVIEW, and `alone = true` for the Labyrinth's reason: its weight is a 140-health storm that is
-- not on the board at the bell, and a stat-line rating of two tier-2 bodies cannot see it (Descent's light-fight
-- filter would drop the fight it cannot rate). Played out, never walked off.
return {
    name = "Dirty Thunder",
    kind = "elite",
    weight = 1,
    alone = true,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function()
        return { "character_blaze", "character_arc" }
    end,
    objective = { type = "killAll" },
}
