-- A wand, so it owes the family's contract (docs/weapons.md): ranged magical, and no `minRange` dead
-- zone. What it adds over data/items/weapon/weapon_wand.lua is that the bolt does not stop when it lands
-- -- it sets the tile alight (data/hazards/hazard_fire.lua), leaving ground that burns whoever stands in
-- it and creeps into any forest it can reach.
--
-- The extra is the mage's own class vocabulary miniaturised: hazard creation is what the Arcanum's shelf
-- IS (Fireball, Rain, Quicksand all remake the ground), and this is the first rung of it -- the entry
-- price for a mage who wants to fight the board instead of the body. A wand asks how much damage it can
-- do. This one asks where the enemy is willing to stand.
--
-- Which makes it feeble and slow to kill anything, deliberately: it wants a corridor, a doorway, or dry
-- forest, and against a foe standing in the open on bare stone it is simply a worse wand. The fire is
-- unsided, as fire always is -- it burns your line exactly as happily, so it is a wall you have to be
-- willing to stand behind.
return {
    name = "Emberwand",
    description = "Looses a bolt at range that sets the ground alight where it lands.",
    flavor = "The Arcanum teaches that fire is a tool. It also teaches that tools are held at arm's length.",
    sprite = "assets/items/emberwand.png",
    type = "weapon",
    tags = { "wand", "magical", "fire", "ranged" },
    class = "mage",
    price = 200,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true, -- a bolt needs a clear line, as every wand's does
        speed = 3,
        cost = { stat = "mana", amount = 5 },
        damage = { 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 9 }, -- under a plain wand's: the ground it leaves is the rest
        effect = function(fx)
            fx.damage(fx.target)
            -- The ember: ground that burns where the bolt struck. Scales off the item's level the way
            -- every hazard-laying cast does (fx.level -- see ability_fireball), since this ability's one
            -- authored magnitude is already its damage. Shorter-lived than a Fireball's blaze: this is a
            -- single ember, not an inferno.
            fx.placeHazard(fx.target.x, fx.target.y, "hazard_fire", { amount = 3 + fx.level, duration = 8 + fx.level })
        end,
    },
}
