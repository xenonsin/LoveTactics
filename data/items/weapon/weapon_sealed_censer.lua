-- A censer, so the smoke is the weapon (docs/weapons.md). Its cloud is hazard_gagging_storm -- screaming
-- static in which nothing standing can spend mana on a working at all.
--
-- Quest-only: `class` with no `price`.
--
-- A carried anti-caster bubble, and the hardest counter to magic in the game precisely because it is not
-- aimed at anybody. A Silence is a spell cast at one body, which a warded target resists and a second
-- caster simply steps around. This is a fact about the ground the priest is standing in, it cannot be
-- resisted, cleansed or dispelled off the victim, and it moves.
--
-- What it means to play is that the priest becomes the front line against an Arcanum warband: walk into
-- the enemy caster cluster and sit there. They cannot cast, they cannot silence you back (their silence
-- is itself a working), and the only answer available to them is to physically kill the priest or
-- physically leave -- both of which are turns spent not casting.
--
-- Unsided and it matters enormously: your OWN mage cannot spend mana inside it either, and neither can
-- the priest carrying it. This is a weapon that turns off half your own party, so it belongs in a company
-- built out of steel with one priest in it -- which is exactly the company that otherwise loses to
-- casters.
--
-- Read against data/items/weapon/weapon_gag_crook.lua, which does the same job as a wait swap on
-- adjacent enemies only: that one is precise, costs a turn, and spares your own line. This is
-- indiscriminate, costs nothing, and never stops.
return {
    name = "The Sealed Censer",
    description = "Wreathes you in screaming static: nothing standing near you can spend mana on anything. Nothing.",
    flavor = "The Cathedral swung it through the Arcanum's great hall exactly once, and the treaty that followed is four hundred pages long.",
    sprite = "assets/items/sealed_censer.png",
    type = "weapon",
    tags = { "censer", "impact", "physical", "melee" },
    class = "priest",
    incense = {
        hazard = "hazard_gagging_storm",
        radius = 1,
        amount = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
    },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        -- Stamina, as every censer's strike is -- which is the joke and also the design: the one weapon
        -- that turns off magic is itself perfectly usable inside its own storm.
        cost = { stat = "stamina", amount = 6 },
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
