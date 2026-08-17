-- CARRION SWARM: nothing here can beat you, and that is not the same as nothing here mattering.
--
-- Four crawlers, each of which would rather eat a fallen body than fight a standing one. Individually
-- they are the cheapest chaff on the floor. Collectively they mean that the moment ANY of your company
-- goes down, the revive stops being a thing you will get to and becomes a thing you are racing for
-- (data/items/weapon/weapon_carrion_jaws.lua).
--
-- The most interesting property of this fight is that it is easy right up until it isn't, and what
-- flips it is a mistake you made two turns earlier.
return {
    name = "Carrion Swarm",
    kind = "combat",
    weight = 3,
    minDay = 3,
    composition = function(ctx)
        local list = {}
        for _ = 1, 3 + math.floor((ctx.day or 1) / 18) do
            list[#list + 1] = "character_carrion_crawler"
        end
        return list
    end,
}
