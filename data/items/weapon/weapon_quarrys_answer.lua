-- A bow, so it owes the family's contract (docs/weapons.md): ranged physical, `requiresSight`, a dead
-- point-blank band, and two hands. What it adds over data/items/weapon/weapon_iron_bow.lua is a
-- REFLEX -- it shoots back. A shot taken at its bearer from anywhere inside the bow's own band is
-- answered with an arrow, for a shot's stamina and none of the timeline.
--
-- The extra is the reach rule read from the far side (models/trait.lua, Trait.mayCounter). Every other
-- answering weapon in the game is a blade, so "can they reach me?" has always meant "are they beside
-- me?" -- and the bow is the weapon that inverts it. This one answers precisely what a sword cannot,
-- and cannot answer what a sword lives on: the counter is bound to the GRANTING weapon's band, so its
-- `minRange` dead zone is a dead zone for the reply too. Close on it and the reflex switches off
-- entirely. That is the counter to the counter, and it is a fact on the board rather than a timer.
--
-- The Lodge sells it to the archer who keeps being flanked by other archers. Against a line that walks
-- at you it is simply an iron bow, and a dearer one.
--
-- It carries Ranged Counter natively, which the Reprisal Quiver (data/items/utility/utility_reprisal_quiver.lua)
-- also grants -- deliberately, on docs/weapons.md's "overlapping an existing charm is fine" rule. The
-- two are not the same reflex in practice: the quiver owns no weapon, so it answers with whatever in
-- the grid reaches, while this one answers with ITSELF and nothing else. Carry both and the archer
-- answers twice for the doubled price, which is what the escalating answer cost is there to bound.
return {
    name = "Quarry's Answer",
    description = "Shoots back at anyone who shoots you from within its own range. No reply at point-blank.",
    flavor = "The Lodge stocks it under 'defensive'. The deer, if consulted, would file it elsewhere.",
    sprite = "assets/items/quarrys_answer.png",
    type = "weapon",
    tags = { "bow", "pierce", "physical", "ranged" },
    hands = 2, -- every bow is two-handed (docs/weapons.md)
    class = "hunter",
    price = 340,
    repRank = 3,
    -- The whole of the extra. Weapon-borne, so Trait.mayCounter binds it to this bow's band and this
    -- bow's dead zone -- a dagger sharing the grid lends it nothing, and it lends the dagger nothing.
    traits = { "trait_ranged_counter" },
    activeAbility = {
        target = "enemy",
        range = 3,
        minRange = 2,         -- a bow has no point-blank shot -- and so no point-blank answer
        requiresSight = true,
        speed = 2,
        cost = { stat = "stamina", amount = 7 }, -- an answer is a swing, so this is also what a reply costs
        damage = { 5, 6, 6, 7, 8, 8, 9, 9, 10, 11, 11 }, -- barely over an iron bow's: the reflex is the price
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
