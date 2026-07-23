-- A Witchlight Flare: a twist of ground glass and salt that burns with a hard colourless light.
-- Anything standing in it is lit up and can be aimed at, however well it is hidden
-- (data/hazards/hazard_witchlight.lua).
--
-- THE ANSWER TO HIDING, which this game did not have. Invisibility, decoys and Stillshade all say "you
-- may not aim at me" (Status.untargetable), and the only reply available was to wait it out -- which
-- is patience, not counterplay. This is a consumable somebody gave up a slot for and a turn throwing,
-- and it works the way ground works: it is somewhere, it is not everywhere, and the rogue gets to walk
-- out of it.
--
-- What the flare really buys is not a reveal but a REGION THE ENEMY MAY NOT HIDE IN, which is a much
-- more interesting thing to have to place well. Thrown at the tile a vanished assassin was standing on
-- it usually finds nothing; thrown across the ground between them and your priest, it makes the
-- approach itself impossible to make unseen.
--
-- It also DISPELS on landing -- the same sweep Dispel Illusions makes (Combat.dispel: reveal the
-- hidden, tear down illusion walls) -- so a flare into a conjured barrier both lights the ground and
-- takes the wall down. That is deliberate: a light and an illusion are the same argument, and the item
-- should not need two of them.
--
-- IT LIGHTS YOUR OWN PEOPLE TOO. A light does not check heraldry, and a party that scatters flares
-- carelessly through its own line will find out what that costs the moment their rogue wants to
-- disappear.
return {
    name = "Witchlight Flare",
    description = "Throws a hard light: nothing standing in it can hide from being targeted.",
    flavor = "Ground glass, salt, and a grudge. The Undercroft sells them and pretends to disapprove.",
    sprite = "assets/items/consumable_witchlight_flare.png",
    type = "consumable",
    tags = { "light" },
    price = 90, -- no class: the Market stocks it, and every party should carry one
    repRank = 1,
    maxStack = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        speed = 2, -- fast: it answers something that has already happened
        consumesItem = true,
        support = true, -- it lands no damage at all
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            -- The sweep first: reveal whatever was hidden and tear down illusion walls across the
            -- footprint, exactly as Dispel Illusions does. Then the ground, which is what keeps them
            -- revealed for as long as they stand in it.
            fx.dispel()
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_witchlight", { duration = 10 + fx.level })
            end
        end,
    },
}
