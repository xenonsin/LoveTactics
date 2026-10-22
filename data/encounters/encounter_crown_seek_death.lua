-- SEEK DEATH: the Reaper and its swarm ("The Crown's Bestiary", slice C, approved 2026-10-09). One Reaper and two or
-- three Pit Locusts, and the lesson is to keep health high, not just above zero: the locusts cannot kill anybody, but
-- they hold a body at 1, and 1 is under the Reaper's line (trait_seek_death, weapon_reapers_scythe).
--
-- A STRAY DELVER OPENS HURT (the objective pass, 2026-10-21), one locust bite above the Reaper's line, and the
-- Reaper downs anyone under a quarter. Keeping health high is the lesson, and now it is a stranger's too.
--
-- The Reaper is listed first, so a ceiling that cuts this fight (Arena.clampComposition) takes a locust and never the
-- reason the locusts matter. No `rung`: the underworld's ground is its pin.
local Band = require("models.band")

return {
    name = "Seek Death",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        local list = { "character_reaper" }
        return Band.fill(list, ctx, "character_pit_locust", { base = 2, min = 2, max = 3 })
    end,
    allies = { "character_stray_delver" },
    objective = {
        type = "killAll", enemy = "the Reaper and its swarm",
        protect = "character_stray_delver", chargeOpens = { health = 0.3 },
    },
}
