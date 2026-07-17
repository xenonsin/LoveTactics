-- The censer archetype: a weapon whose weapon is not the strike (docs/weapons.md). It emits `incense` --
-- a square of ground around its bearer that is lifted and laid again wherever they go (Combat.layIncense).
-- Allies caught in the smoke are Blessed (data/hazards/hazard_incense.lua).
--
-- The family in one line: a banner is ground that STAYS, a trail is ground you LEAVE BEHIND, and a censer
-- is ground that WALKS. All three are the same machinery -- a zone, and a status that decides whether it
-- clings (see the header of models/hazard.lua) -- pointed in three directions.
--
-- What it costs is that the blessing is a LEASH, not a gift. Blessing declares no `lingers`, so it is
-- zone-bound: it holds for exactly as long as the smoke is over you and lifts the moment the priest walks
-- off with it (Hazard.reap). The censer does not buff your line; it buffs whoever is willing to stay next
-- to the priest, which is a position the enemy can read as easily as you can.
--
-- The Cathedral's entry-rank arm, and the priest's plainest: no edge, no forged blade, no reach. See
-- data/items/weapon/weapon_censer_of_ashes.lua for the same family read from the other side -- the
-- censer belongs to this shelf and no other, so both of its directions are lust's.
return {
    name = "Censer",
    description = "Wreathes you in smoke: allies standing beside you are Blessed.",
    flavor = "The smoke goes where the priest goes. So, in the end, does everyone else.",
    sprite = "assets/items/censer.png",
    type = "weapon",
    tags = { "censer", "impact", "physical", "melee" }, -- swung on its chain; the strike is the afterthought
    class = "priest",
    price = 120,
    repRank = 1,
    -- The cloud: which ground it lays, how far it reaches, and how deep the Blessing runs. `amount` rides
    -- in as the granted status's magnitude and climbs with the forge; `radius` deliberately does NOT --
    -- an upgrade buys a stronger blessing, never a wider one (models/item.lua).
    incense = {
        hazard = "hazard_incense",
        radius = 1, -- the 3x3 the bearer stands in the middle of
        amount = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
    },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 }, -- feeble on purpose: the smoke is the weapon
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
