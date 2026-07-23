-- A dagger, so it is quick and it opens a wound (docs/weapons.md). Its extra is that the two halves land
-- in different schools: the strike is `magical` -- turned by Magic Defense, and armour has nothing to say
-- about it -- while the Bleed it leaves is `raw` as every bleed is, turned by nothing at all.
--
-- Quest-only: `class` with no `price`.
--
-- The only weapon in the game that attacks two different defenses in one swing on one pool. Every other
-- multi-school thing here pays for the privilege: weapon_crescent_blade spends mana AND stamina for its
-- magical arc, and the whole of docs/weapons.md's multi-pool section exists to price that. This one
-- spends a dagger's five stamina and simply refuses to be categorised.
--
-- What that means in play is that nothing the enemy can wear is right. Plate turns the bleed and not the
-- stab; a ward turns the stab and not the bleed; the two together are the only answer and almost nobody
-- is carrying both. Against a mixed enemy line it is the most reliably-landing weapon on the rogue's
-- shelf, which is what a knife with almost no damage on it needs to be.
--
-- Bleed staying raw is not an oversight, it is the family contract (docs/weapons.md: "armor turns a
-- blade, but does nothing about a wound already open"). The deviation here is only the strike.
return {
    name = "The Thin Place",
    description = "A quick magical cut that leaves an ordinary bleed: the stab is turned by wards, the wound by nothing.",
    flavor = "The Undercroft's fences will not handle it. They say the blade is thinner than the space it goes into.",
    sprite = "assets/items/thin_place.png",
    type = "weapon",
    -- `magical` in place of the family's usual physical: this is the deviation and the weapon.
    tags = { "dagger", "pierce", "magical", "melee" },
    class = "rogue",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- the family contract: a dagger is quick (tests/weapon_spec.lua)
        -- Stamina, not mana. A rogue swings it, and what is magical is the wound rather than the work --
        -- the same line data/items/weapon/weapon_whitening.lua draws for the greatsword.
        cost = { stat = "stamina", amount = 5 },
        -- Measured against Magic Defense, which the armoured bodies a rogue struggles with have bought
        -- almost none of. Modest on paper; most of it arrives.
        damage = { 5, 5, 6, 6, 7, 8, 8, 9, 10, 10, 11 },
        effect = function(fx)
            fx.damage(fx.target) -- tags default to the item's, so the cut is magical
            fx.applyStatus(fx.target, "status_bleed")
        end,
    },
}
