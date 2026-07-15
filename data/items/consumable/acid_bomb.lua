-- Crucible rank-2. A flask of caustic brew that bursts in a small blast and eats the ARMOR off
-- everything caught in it: each victim is left Corroded (data/status/acid.lua), its defense and magic
-- defense cut for a time. It does modest damage of its own -- the point is what comes next. Soften a
-- heavily-plated line with a bomb, then let the party's real hitters land on bare skin.
--
-- The alchemist's take on "removing armor": not stealing the plate (that is Greed) but making it stop
-- working (Envy). Carries no "magical" tag; the corrosion cares nothing for magic defense to apply.
return {
    name = "Acid Bomb",
    description = "A caustic flask. Bursts and eats away the armor of those it splashes.",
    sprite = "assets/items/acid_bomb.png",
    type = "consumable",
    tags = { "acid" },
    class = "alchemist",
    price = 150,
    repRank = 2,
    activeAbility = {
        target = "enemy", -- thrown at a foe and bursts around it, like Fireball
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        damage = { 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12 }, -- flat, modest: the debuff is the payload, not the splash
        consumesItem = true,
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
                fx.applyStatus(u, "acid")
            end
        end,
    },
}
