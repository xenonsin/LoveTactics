-- LIVERY OF THE HOUSE: the Elf Retainer's drop, worn (data/items/armor/armor_livery_of_the_house.lua). Approved
-- 2026-09-30 ("Pride's Bestiary"). A retainer's coat is worn to be seen unmarked: +3 Defense while the wearer is
-- at full health, a live bonus (Trait.liveBonus) that is gone with the first wound and back with the last heal.
local Combat -- lazy: trait files load before combat.lua is wanted

return {
    name = "Livery of the House",
    description = "While at full health, increase defense by 3.",
    live = function(ctx)
        local u = ctx.unit
        local hp = u and u.char and u.char.stats and u.char.stats.health
        if not hp then return nil end
        Combat = Combat or require("models.combat")
        if (hp.current or 0) >= Combat.unreservedMax(u.char, "health") then return { defense = 3 } end
        return nil
    end,
}
