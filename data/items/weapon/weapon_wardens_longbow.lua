-- A longbow, so it is drawn before it looses and reaches five tiles (docs/weapons.md). Its extra is that
-- the draw can be DEEPENED: `windup = { min, max }` lets the archer pour up to three extra ticks into it,
-- and every one of them puts more behind the shaft.
--
-- The family's second rung, and the one that teaches what a longbow is for. An iron longbow's bargain is
-- fixed -- one turn of draw, one heavy arrow -- and a new archer reads that as strictly worse than
-- shooting twice with a bow. This makes the bargain adjustable, so the player finds out for themselves
-- that the correct depth depends entirely on how long they think they have.
--
-- It is the chargeable channel Saber's signature introduced (data/items/weapon/weapon_first_motion.lua),
-- and the only shop weapon that carries one. Where hers pours ticks into arithmetic about the target's
-- health, this pours them into the plain number -- deliberately the simplest possible use of the
-- mechanic, because this is where a player meets it first.
--
-- The cost is the cost of every long draw: hard control breaks it, and three extra ticks is a long time
-- to stand still in front of something that can reach you.
return {
    name = "Warden's Longbow",
    description = "Drawn over a full turn, and held longer for a heavier shaft -- up to three extra ticks of draw.",
    flavor = "A warden's watch is mostly waiting. The bow was made by someone who understood that this was the skill.",
    sprite = "assets/items/wardens_longbow.png",
    type = "weapon",
    tags = { "longbow", "pierce", "physical", "ranged" },
    hands = 2, -- two-handed, like every bow
    class = "hunter",
    price = 300,
    repRank = 2,
    activeAbility = {
        description = "Hold the draw longer for a heavier shaft: each extra tick adds a quarter of the shot.",
        target = "enemy",
        range = 5,    -- the family's reach: two tiles past a bow
        minRange = 2, -- and the family's dead zone
        requiresSight = true,
        speed = 4,
        channel = 2,                  -- the base draw
        windup = { min = 0, max = 3 }, -- ...and up to three more ticks, chosen at cast
        cost = { stat = "stamina", amount = 9 },
        -- Under the iron longbow's, read as the UNDEEPENED number: drawing to the same depth as an iron
        -- longbow should land a little short of it, and the extra ticks are what buys past it.
        damage = { 8, 9, 10, 11, 12, 13, 15, 16, 17, 18, 19 },
        effect = function(fx)
            -- +25% per extra tick poured in. Linear and uncomplicated on purpose -- see the header.
            local held = fx.windup or 0
            if fx.target then
                fx.damage(fx.target, { amount = math.floor((fx.amount or 0) * (1 + 0.25 * held)) })
            end
        end,
    },
}
