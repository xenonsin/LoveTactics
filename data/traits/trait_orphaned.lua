-- ORPHANED: the other direction of the bond, and the only quiet moment in the fight.
--
-- trait_bereaved is what happens to her when the cub falls. This is what happens to the cub when SHE
-- does: it does not fight on. A yearling alone does not press an attack on four armed people, and a
-- fight that ended with the party grinding down a cub whose mother is already dead would be the one
-- beat in this design that says nothing.
--
-- IT RIDES ON HER RELIC, NOT ON THE CUB. utility_the_year_behind_her carries both halves of the bond
-- because the bond is one object, and because character_bear is ROAD STOCK -- the ordinary animal in
-- encounter_bear, met on its own with no sow anywhere. A rule about mothers has no business on that
-- sheet, where it would sit dead in every fight but one and still be read by anybody opening the file.
-- Hung on her, it exists exactly where the fight that needs it does.
--
-- DISMISSED, NOT KILLED. Combat.dismiss is the verb for a body leaving the field without dying -- it
-- logs as vanishing rather than as a defeat, and it is what keeps this from paying out like a kill:
-- no spoils, no Engorge, no execute credit, nothing that counts corpses counts this one. The animal
-- left; nobody felled it. (Nil-safe by construction: dismiss no-ops on a body that is already down, so
-- a cub the party killed first is simply not there to run.)
--
-- Fired from killUnit before her summons are dismissed (models/trait.lua's onDeath). She summons
-- nothing, so there is no ordering question here -- but the hook is the same one, and if she is ever
-- given a summon this runs first and the cub still leaves.
-- The require lives INSIDE the hook, as every other file in this folder does it: Trait.defs is built by
-- Registry.load while models/trait.lua is still loading, and models/combat.lua requires models/trait.lua,
-- so a top-level require here reaches into a half-built module.
return {
    name = "Orphaned",
    description = "If she falls, her cub leaves the field.",
    cub = "character_bear", -- the same id trait_bereaved reads; one bond, one blueprint named twice
    onDeath = function(ctx)
        local Combat = require("models.combat")
        local u = ctx.unit
        if not (u and ctx.combat) then return end
        for _, other in ipairs(ctx.combat.units or {}) do
            if other ~= u and other.alive and other.side == u.side
               and other.char and other.char.id == ctx.def.cub then
                Combat.dismiss(ctx.combat, other, string.format("%s will not stay without her.",
                    (other.char and other.char.name) or "The cub"))
            end
        end
    end,
}
