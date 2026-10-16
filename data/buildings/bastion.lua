-- THE BASTION: the knights' house, and the city's one FORGE.
--
-- ITS SHELF is an order's armoury -- the plate, and the oath that goes with it -- deepening as the
-- roster's knight level climbs (Quest.shelfRung) rather than opening whole.
--
-- AND ITS SECOND ROOM IS THE FORGE. Vendors sell; this is where gear climbs, and it is one of the two
-- rooms that spend MATERIALS (models/forge.lua). An order's armoury is where plate is kept, and
-- keeping plate is maintenance -- so the forge belongs behind the door the player has been walking
-- into since Rowan swore, rather than on a plate of its own.
--
-- WHAT IT WORKS IS WHAT A SMITH CAN HOLD IN A PAIR OF TONGS: a weapon, a coat, a piece of kit -- plus
-- mending them and breaking them down, neither of which is a rung. An ability and the recipe behind a
-- draught climb the same ladder in the Arcanum's study, because honing a spell is reading it more
-- exactly and no amount of heat does that (data/buildings/arcanum.lua argues the other half).
--
-- THE ROOM IS CALLED THE FORGE, not the bench. `forge` is the word on the panel, in the docs and in
-- every conversation about it, and the player met it as a building before it was a room -- so the desk
-- says the name they already have. "Bench" survives in this file only as the common noun.
--
-- THE FORGE WAITS FOR THE THIRD TRIP HOME, and the argument is the old floor-four one on the right
-- clock: what it spends is salvaged a handful at a time out of the fighting (models/spoils.lua), so a
-- company one trip in is reading a ladder for gear it has not found yet. Three trips is roughly where
-- the stock is deep enough that a rung is a real purchase, and by then the player has a weapon they
-- have decided they like, which is the only thing an upgrade bench is any use for.
--
-- IT IS THE HEAVIEST LESSON IN THE CITY -- two currencies, a ladder, ceilings, materials -- which is the
-- other reason it is third rather than first. Selling and a supper are one verb each; this is a system.
return {
    name = "The Bastion",
    order = 4,
    x = 835,
    y = 120,
    w = 270,
    h = 130,
    vendor = "bastion",
    -- The desk: what this house says on the way in, and the rooms it offers (models/counter.lua).
    counter = "conversation_bastion_counter",
    offers = {
        -- THE SHELF OPENS ON THE CITY SCHEDULE (models/offer.lua's Offer.SCHEDULE): one house's shelf per
        -- trip home, in a fixed order, unless a body unlocks this house's class first -- that pulls
        -- the shelf into the next trip's slot. Once open it stays open, and it announces its house:
        -- the plaza grows by one shopfront a homecoming. A class level still buys DEPTH and nothing
        -- else (Quest.shelfRung): level 0 is rung 0, the bottom band.
        { answer = "shelf", panel = "shop", gate = { city = "bastion.shelf" } },
        { answer = "forge", panel = "forge", gate = { city = "bastion.forge" } }, -- see the header
    },
    description = "The plate, the oath that goes with it, and the forge that keeps both.",
}
