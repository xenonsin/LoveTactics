-- A dagger, so it is quick and it bleeds (docs/weapons.md). Its extra is Mired (status_mired) on top of
-- the wound: movement and ability costs doubled for whoever it cuts.
--
-- Quest-only: `class` with no `price`.
--
-- The two debuffs close the same door from both sides, which is the whole design. Bleed is a question the
-- victim answers by standing still -- it costs damage per tile walked and nothing at all for holding
-- position (data/status/status_bleed.lua). Mired is the answer to the answer: standing still is now the
-- expensive option too, because every ability the victim casts from that tile costs double. There is no
-- correct move left. Walk and bleed, or act and pay twice.
--
-- Read it beside data/items/weapon/weapon_envenomed_kris.lua, which makes the same argument with Poison
-- -- Bleed taxes moving, Poison taxes waiting. This is the third corner: Poison punishes the clock, and
-- Mired punishes the ACT. A rogue with both krisses has taxed movement, time, and action, which is
-- everything a turn is made of.
--
-- Its own damage is the worst on the shelf, and that is correct. Nothing about this knife is the knife.
return {
    name = "The Mired Kris",
    description = "A quick, bleeding cut that also Mires: moving costs blood, and acting costs double.",
    flavor = "The Undercroft does not sell it to people who want someone dead. It sells it to people who want someone stuck.",
    sprite = "assets/items/mired_kris.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "melee" },
    class = "rogue",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        -- Under an iron dagger's, which is already the modest end of the game. Two debuffs is the sale.
        damage = { 3, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9 },
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_bleed")
            fx.applyStatus(fx.target, "status_mired")
        end,
    },
}
