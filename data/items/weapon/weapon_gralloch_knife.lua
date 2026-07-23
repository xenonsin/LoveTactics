-- Gula's grid weapon, and gluttony's reading of the hunter's kit the way the Censer of Ashes is lust's
-- (docs/story.md, "The Hunter's Lodge"). A gralloch is the gutting stroke that opens a carcass to be
-- dressed; read as consumption, it is heal-on-hit -- the blade that eats what it cuts.
--
-- The heal rides in the effect itself (fx.heal(fx.user)), the mechanic already shipped on the Parasitic
-- Staff (data/items/weapon/weapon_parasitic_staff.lua) -- no new engine. Her relic carries the same
-- appetite as a passive for whoever lifts it (data/traits/trait_ravenous.lua on
-- data/items/utility/utility_maw_of_the_unfed.lua), so the grind that feeds her in her own grid is the
-- grind she hands you when you wear her key.
--
-- A boss weapon: no `class`, no `price`. It is fast and cheap so she swings often -- every swing a meal.
return {
    name = "Gralloch Knife",
    description = "Guts what it cuts: heals the wielder for a share of the wound on every hit.",
    flavor = "The stroke that opens a carcass to be dressed. On her it never stops at the carcass.",
    sprite = "assets/items/gralloch_knife.png",
    type = "weapon",
    -- `relic`, like every general's weapon (armor_mail_of_the_unappeased, weapon_forsworn_pike): it says
    -- in the data what this file's header has always said in prose, which is that this is Gula's and not
    -- part of the dagger family's ten (docs/weapons.md). Nothing reads the tag mechanically -- it is what
    -- keeps a sin's weapon out of a count of the shelf.
    tags = { "dagger", "pierce", "physical", "melee", "relic" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- quick: she acts again almost at once, and each strike feeds her
        cost = { stat = "stamina", amount = 4 },
        damage = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 },
        effect = function(fx)
            fx.damage(fx.target)
            fx.heal(fx.user, 8) -- she eats what she cuts, the same shape parasitic_staff refills mana on hit
        end,
    },
}
