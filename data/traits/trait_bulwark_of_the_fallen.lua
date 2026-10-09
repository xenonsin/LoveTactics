-- BULWARK OF THE FALLEN: the Death Knight's rule, and the Sentinel's Oathbound Plate once it is carried out
-- (data/items/utility/utility_bulwark_of_the_fallen.lua, armor_oathbound_plate.lua). Reviewed 2026-10-09 ("The
-- Crown's Bestiary", slice B).
--
-- When any ally falls within `reach` of the bearer, the fallen ally's armour closes over it as a Physical Barrier
-- worth `share` of that ally's max health (models/crown_demons.lua's bulwark). The barrier pays physical wounds
-- out of that amount and lets magic straight past -- the third counter the review names, beside killing the
-- knight first and fighting its escort outside its 3 tiles.
return {
    name = "Bulwark of the Fallen",
    description = "When an ally within 3 falls, gain a Physical Barrier of half its max health.",
    share = 0.5,
    reach = 3,
    onAnyDeath = function(ctx)
        require("models.crown_demons").bulwark(ctx.combat, ctx.unit, ctx.fallen,
            ctx.param("share", 0.5), ctx.param("reach", 3))
    end,
}
