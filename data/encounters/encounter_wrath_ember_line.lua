-- THE EMBER LINE: the Wrath circle's ordinary traffic, and the stratum's rule at the cheapest rung.
--
-- Every body here leaves fire on the tile it dies on, so the fight rearranges the board as you win it.
-- Clear the swarm and you have won the exchange and lost the room -- which is what makes the deeper
-- stops of this circle work, because the Unquenched drinks that fire and the Anvil is paid for the
-- trades you take when you can no longer kite.
--
-- Locked to the volcanic stratum by ctx.biome, the same gate every circle uses.
return {
    name = "The Ember Line",
    kind = "combat",
    weight = 5,
    minDay = 1,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    composition = function(ctx)
        local list = { "character_cinder_kin" }
        for _ = 1, 3 + math.floor((ctx.day or 1) / 14) do
            list[#list + 1] = "character_ember_spit"
        end
        return list
    end,
}
