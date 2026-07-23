-- A censer, so the smoke is the weapon (docs/weapons.md). Its cloud is hazard_bloodsong -- red smoke in
-- which allies drink back a share of everything they deal.
--
-- The Cathedral's top rung, and lust read as appetite rather than as devotion. Where the plain censer's
-- blessing raises what your line DEALS, this returns what your line TAKES -- so it is worth nothing to a
-- party standing still and enormous to one that is swinging. A knight in the red smoke heals for holding
-- the doorway; a rogue in it heals for every cut.
--
-- What it changes about how a priest is played is the direction they walk. Every other Cathedral item
-- rewards being reachable -- stand where the wounded can get to you. This rewards being where the DAMAGE
-- is, because lifesteal on nobody is nothing, and the priest has to push into the melee to make the smoke
-- worth carrying.
--
-- It stacks with a Vampiric Strike charm and with a weapon's own declared `lifesteal` rather than
-- overriding either (docs/weapons.md), so a Crimson Greataxe swung inside this is drinking from two
-- sources at once -- which is the intended, and the reason it sits where it does on the shelf.
return {
    name = "Censer of the Red Hour",
    description = "Wreathes you in red smoke: allies standing in it drink back a share of everything they deal.",
    flavor = "The Cathedral files it under mercy, on the grounds that it keeps people alive. The filing is not popular.",
    sprite = "assets/items/censer_red_hour.png",
    type = "weapon",
    tags = { "censer", "impact", "physical", "melee" },
    class = "priest",
    price = 620,
    repRank = 4,
    incense = {
        hazard = "hazard_bloodsong",
        radius = 1,
        amount = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
    },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
