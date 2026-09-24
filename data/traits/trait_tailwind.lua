-- Tailwind: a wyvern's whole defence, and the reason it survives a wood full of bigger animals. It does not
-- out-muscle anything; it stays where nothing is standing beside it, and there it is hard to hit.
--
-- A LIVE passive (Trait.liveBonus -> flatStat -> Combat.avoid): +`avoid` while no foe is within a tile,
-- and nothing at all the moment one is. That is the counterplay written into the number -- close the gap
-- and the wind drops -- and it is why the wyvern's Wind Shear cannot be thrown at anything adjacent.
--
-- IT IS ALSO WHERE LEAD THE WIND LANDS. An Alpha Wyvern within its radius, not itself Aloft, lends every
-- Tailwind carrier near it its own Avoid on top, and keeps lending it with a foe beside them -- which is
-- what makes the alpha the kill order (trait_lead_the_wind). Read here, on the receiving body, because a
-- live bonus is a claim about the bearer as it stands and the bearer is who is being shot at.
--
-- 25 on the animal; the company's Tailwind Charm carries 15 (`traitParams`), because a person chooses
-- where to stand and a wyvern is only choosing where to fly.
return {
    name = "Tailwind",
    description = "+25 Avoid while no foe is adjacent.",
    avoid = 25,
    live = function(ctx)
        if not ctx.combat then return nil end
        local Combat = require("models.combat")
        local Status = require("models.status")
        local Trait = require("models.trait")
        local unit, total = ctx.unit, 0
        if ctx.count(1, "enemy") == 0 then total = total + Trait.param(ctx.trait, "avoid", 25) end
        for _, other in ipairs(Combat.unitsNear(ctx.combat, unit.x, unit.y, 3)) do
            if other ~= unit and other.alive and other.side == unit.side
                and not Status.has(other, "status_aloft") then
                local lead = Trait.flag(other, "leadsTheWind")
                if lead and Combat.unitGap(unit, other) <= (lead.def.radius or 3) then
                    total = total + (lead.def.avoid or 15)
                    break -- one alpha's wind is the wind; two do not blow twice as hard
                end
            end
        end
        if total == 0 then return nil end
        return { avoid = total }
    end,
}
