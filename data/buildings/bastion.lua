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
        -- THE SHELF IS NEVER GATED, because the shelf IS the house. Under the card era a shut shelf
        -- hid the whole shopfront, so the gate and the door were one fact; the fold put these doors on
        -- the plaza for OTHER rooms' sake, and the gate started meaning "walk through a shopfront and
        -- be offered no shop" -- which is what every desk in the city shipped reading.
        --
        -- A CLASS LEVEL BUYS DEPTH NOW and nothing else, which is the job Quest.shelfRung already
        -- describes itself doing: level 0 IS rung 0, the class's bottom band, and the ladder unlocks
        -- upward from there. Under the level-1 gate nobody could ever see rung 0 at all.
        --
        -- QUIET all the same: a shelf never puts a card on the plaza. A class rung is a reward the
        -- player cannot see, and hanging a door on it put shopfronts in the city that nobody chose to
        -- earn (models/offer.lua's Offer.any).
        { answer = "shelf", panel = "shop", quiet = true,
          -- ...except to the company training for it (models/offer.lua's `declared` gate).
          -- A shelf is not a deed the player can feel, so it stays quiet; taking up the class
          -- it sells IS one, and it is the only thing that puts this card on the plaza early.
          announce = { declared = true } },
        { answer = "forge", panel = "forge", gate = { trips = 3 } }, -- see the header
    },
    description = "The plate, the oath that goes with it, and the forge that keeps both.",
}
