-- FOOL'S GOLD: their greed, used against them. Drops off the Dwarf Porter as a trapper's piece (reviewed
-- 2026-09-24, "The Dwarves of Greed").
--
-- Lays a false coin heap (data/hazards/hazard_fools_gold.lua). The first foe to step on it catches Gold
-- Fever -- driven at the company body nearest the heap that is NOT the one who laid it. So the trapper
-- picks the bait by where the tank is standing. Dwarves see it from anywhere: it welcomes a heap-seeker
-- exactly as a real heap does, so on a dwarf fight it draws them off whatever they were doing.
return {
    name = "Fool's Gold",
    description = "Lays a false coin heap. The first foe to step on it catches Gold Fever toward the ally nearest the heap, not you.",
    flavor = "Painted lead, and a good deal of confidence. It has never needed to be more than that.",
    sprite = "assets/items/ability_fools_gold.png",
    type = "ability",
    tags = { "guile" },
    class = "trapper",
    unlockLevel = 5,
    unstocked = true,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 3,
        cooldown = 15,
        cost = { stat = "stamina", amount = 4 },
        harmless = true,
        effect = function(fx)
            if fx.unitAt(fx.tx, fx.ty) then return end
            local heap = fx.placeHazard(fx.tx, fx.ty, "hazard_fools_gold", { duration = 30 })
            -- Who laid it, so the fever can be pointed at anybody BUT them.
            if heap then heap.layer = fx.user end
        end,
    },
}
