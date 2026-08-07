-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Banks a charge whenever ANYONE nearby works a spell (trait_gleaning) -- the party's casters, the
-- enemy's, it does not care whose. The mantle does not produce magic; it takes a cut of everyone
-- else's. And it SPENDS what it took, itself: the hem is loosed and the whole bank goes up at once as
-- a Magical Barrier over the wearer and everyone standing beside them, one blow warded per three
-- charges.
--
-- IT SPENDS ITS OWN PURSE, and that is a rule rather than a flourish. An item that banks a resource
-- has to be able to spend it too, or it is inert until you happen to also own the thing that does --
-- see Answering Blow, which declares Defiance itself for exactly this reason. This mantle banked and
-- never spent: it was a stat stick wearing a counter it could not reach, and the description promised
-- a charge that bought nothing.
--
-- THE FILL AND THE PAYOFF ARE THE SAME CONDITION, which is the whole item. A Magical Barrier stops
-- magic and nothing else, and this only fills off magic -- so the mantle is worth exactly as much as
-- the fight is magical, at both ends of the exchange. Against a warband of swords it banks nothing all
-- fight and would have warded nothing worth warding anyway. In an Arcanum duel it fills on both sides
-- of the exchange, and the enemy cannot stop feeding it without also declining to cast -- which is to
-- say, without also declining to be the thing it wards against. Which makes it the first piece of gear
-- worth reading the enemy roster before equipping.
--
-- The wearer's own spells never feed it: Trait.onAnyCast skips the caster, so a mage in this mantle
-- banks off their line-mates and off the enemy, never off themselves. You cannot fill your own hem.
-- That is what keeps it a gleaning rather than a battery a caster winds up alone.
--
-- Deliberately NOT a second Gleaning Rod. The rod is this same economy pointed OUTWARD -- a bolt or a
-- healing, aimed, at range. This points inward, at the ring you are already standing in, and wards
-- rather than answers. Charges live per ITEM, so carrying both banks two independent purses off the
-- same casts: a real Arcanum-specialist build, and not a double-dip worth closing -- filling two
-- purses still costs two turns to spend.
--
-- Filed under pride rather than envy, and the line is thin enough to be worth stating: envy covets a
-- specific person's power and spoils it (see the Crucible's shelf). This does not care who cast, takes
-- nothing away from them, and simply assumes the working was partly its own. That assumption is the
-- sin -- and the ward is the assumption made literal, their magic worn as your armour.
--
-- utility_gleaning_rod is the charm form. Cloth: a square of pace.
local Curve = require("models.curve")

return {
    name = "Gleaner's Mantle",
    description = "Banks a charge from every spell cast nearby; spend them all to ward the ring against magic.",
    flavor = "The Arcanum rules that ambient working is unowned. The ruling was written by people wearing these.",
    sprite = "assets/items/armor_gleaners_mantle.png",
    type = "armor",
    tags = { "cloth", "arcane" },
    class = "mage",
    traits = { "trait_gleaning" },
    bonus = { magicDefense = Curve.ramp(4, 14), movement = -1 },
    resist = { magical = 2 },
    activeAbility = {
        description = "Spends the whole bank: a Magical Barrier over you and every adjacent ally, one blow warded per 3 charges.",
        -- Self-centred rather than aimed: the hem covers the ring the wearer is standing in, and there
        -- is nothing to choose about where that is (cf. Answering Blow, built the same way).
        target = "self",
        range = 0,
        aoe = { radius = 1, shape = "square" }, -- the eight tiles around the wearer, corners included
        speed = 4,
        support = true, -- a ward, not a blow: it reads green and lands no damage
        cost = { stat = "mana", amount = 8 }, -- cheap, as the rod's is: the charges are the real price
        -- The purse, banked on the ITEM by trait_gleaning. Surfacing it lets the grid draw the count
        -- (0 when dry) and refuse the cast while it is empty (Combat.itemBlockReason), so an empty
        -- mantle greys out rather than wasting a turn -- the rod and the Reliquary do the same.
        counter = function(_, item) return (item and item.charges) or 0 end,
        counterEmpty = "The hem is empty -- nothing has been worked near it",
        effect = function(fx)
            local charges = fx.item.charges or 0
            if charges <= 0 then
                fx.log("action", "The hem is empty. Nothing has been worked near it.", fx.user)
                return
            end
            -- Spent to nothing, whatever it bought. A purse rather than a rate -- loosing it early for
            -- one warded blow is a real mistake the player will make once.
            fx.bankItem("charges", 0)
            -- Coverage, not size: a ward that negates a hit outright cannot negate it harder, so the
            -- only axis the bank can move is how many blows it stands for (see status_magical_barrier).
            -- Three charges to the blow, floored at one -- a mantle with anything in it wards something.
            local hits = math.max(1, math.floor(charges / 3))
            local duration = 10 + fx.level
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side == fx.user.side then
                    fx.applyStatus(u, "status_magical_barrier", { magnitude = hits, duration = duration })
                end
            end
        end,
    },
}
