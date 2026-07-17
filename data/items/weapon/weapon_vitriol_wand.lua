-- A wand, so it owes the family's contract (docs/weapons.md): ranged magical, and no `minRange` dead
-- zone. What it adds over data/items/weapon/weapon_wand.lua is that the bolt does not try to kill you --
-- it strips you. Every hit lays Acid (data/status/status_acid.lua), eating -6 from BOTH defenses for as
-- long as it clings.
--
-- The extra is envy in mechanical form, and it is why the damage curve sits under a plain wand's. The
-- Arcanum's wand asks "can I out-damage that armor?". This one declines the question and takes the armor
-- away, and then everyone else's hits land harder too. It is a weapon whose damage stat is the rest of
-- your party -- the more of them are swinging, the more the first bolt was worth.
--
-- Which also decides where it goes in a turn order: fire it FIRST. A vitriol bolt thrown after the axe
-- has already landed has corroded armor that is no longer in anyone's way.
return {
    name = "Vitriol Wand",
    description = "Looses a caustic bolt at range, laying Acid: the target's defenses are eaten away.",
    flavor = "It barely stings. That is not what it is for.",
    sprite = "assets/items/vitriol_wand.png",
    type = "weapon",
    tags = { "wand", "magical", "acid", "ranged" },
    class = "alchemist",
    price = 240,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true, -- a bolt needs a clear line, as every wand's does
        speed = 3,
        cost = { stat = "mana", amount = 5 },
        damage = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 }, -- under a plain wand's: what it opens is the point
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_acid")
        end,
    },
}
