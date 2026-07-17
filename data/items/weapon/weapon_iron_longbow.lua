-- The longbow archetype: a bow whose shot must be DRAWN before it flies. The archer spends a turn at
-- full draw (channel), and the arrow leaves on the next one -- from two tiles further out than any
-- plain bow can reach, and with the same dead point-blank band a bow always has.
--
-- Its own family, NOT a bow (docs/weapons.md). A bow's verb is "shoot now, from over there"; a
-- longbow's verb is the draw, and that inverts how the weapon is played. An iron bow trades tempo for
-- safety -- loose, step back, loose again. A longbow cannot do that: it commits a turn before the
-- shot exists, so the range 5 is not a comfort margin but the thing that BUYS the wind-up. You stand
-- where nothing can close on you in the turn you spend drawing, or you don't get the shot at all.
-- Hard control breaks the draw outright.
--
-- This is the same bargain data/items/weapon/weapon_iron_greatsword.lua makes in melee -- a turn spent
-- winding up for a blow nothing else matches -- read across the field instead of into one adjacent
-- tile. Like the greatsword it must not inherit its neighbour family's extras; the longbow is simply
-- a bow that costs a turn and reaches further.
return {
    name = "Iron Longbow",
    description = "Drawn over a full turn, then looses from far beyond a bow's reach.",
    flavor = "You stand where nothing can close on you while you draw, or you do not get the shot at all.",
    sprite = "assets/items/longbow.png",
    type = "weapon",
    tags = { "longbow", "pierce", "physical", "ranged" },
    hands = 2, -- two-handed, like every bow -- and a longbow more literally than most
    class = "hunter",
    price = 190,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 5,     -- two tiles further than data/items/weapon/weapon_iron_bow.lua's 3
        minRange = 2,  -- the point-blank band a bow of any length has: no shot at an adjacent foe
        requiresSight = true, -- an arrow needs a clear arc; terrain cover blocks the shot
        speed = 4,     -- heavier than a bow's 2: a full draw is not a snap shot
        channel = 1,   -- the draw. The shot resolves on the archer's next turn; hard control breaks it
        cost = { stat = "stamina", amount = 9 },
        -- Roughly double the iron bow, which is what the spent turn is worth: over two turns the
        -- longbow lands one shot where the bow lands two, so the trade is reach and one heavy arrow
        -- against tempo. Deliberately short of the greatsword's curve -- that one is paid for in
        -- standing adjacent to what it hits.
        damage = { 10, 11, 12, 13, 15, 16, 17, 18, 20, 21, 22 },
        effect = function(fx)
            -- Single target: whoever is still standing there when the arrow arrives. Like the
            -- greatsword's wind-up, the strike reads the live board -- a foe that walks clear during
            -- the draw simply isn't there to be hit.
            if fx.target then fx.damage(fx.target) end
        end,
    },
}
