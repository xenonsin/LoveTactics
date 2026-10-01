-- RENOWN: the Elf-Lord's (data/items/utility/utility_renown.lua). Approved 2026-09-30 ("Pride's Bestiary"), as an
-- aura. Every kill an elf of his side makes -- his own included, read off the fallen's lastAttacker -- is told to
-- his credit: a stack of Renown (status_renown, +2 Damage and +1 Speed each, for the fight). And every elf of his
-- side within 3 of him takes +1 Damage a stack, a `presence` (Trait.liveBonus) that lends to elves alone and
-- moves with where they stand.
--
-- So the court is the threat in proportion to how well it is doing, and the Lord is the lever: fell him and the
-- count is gone from all of them at once.
local Status -- lazy: status.lua requires trait.lua back

local function isElf(u) return u and u.char and u.char.race == "elf" end

return {
    name = "Renown",
    description = "Every kill an elf of your side makes gives you Renown. Elves within 3 gain damage for each.",
    notAReaction = true,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        local killer = fallen and fallen.lastAttacker
        if not (u and u.alive and killer and fallen.side ~= u.side) then return end
        if killer.side ~= u.side or not isElf(killer) then return end
        ctx.applyStatus(u, "status_renown", { applier = killer })
    end,
    presence = {
        allies = true,
        radius = 3,
        damage = function(bearer, _, unit)
            if not isElf(unit) then return 0 end
            Status = Status or require("models.status")
            return Status.stacksOf(bearer, "status_renown")
        end,
    },
}
