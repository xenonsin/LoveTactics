-- THE HEXBINDER'S CORD: the one item in the game that arrives already cursed, and the Shaman's own
-- demonstration of what his craft costs (models/curse.lua).
--
-- A BLUEPRINT MAY DECLARE `curse`, and this is what that field is for. Every other hex in the game is
-- stamped onto a live instance long after the piece was made -- by a trap, by a caster, by the
-- Touchstone naming a bad find -- and this is the case where the thing was bound before anybody found
-- it. The Clinging Hand takes no stats at all; its whole content is that the piece cannot be put down
-- (data/curses/curse_the_clinging_hand.lua), which is why it is the one safe to sell.
--
-- SO WHAT IS ACTUALLY BEING BOUGHT IS A CELL. The charm's numbers are frankly good for their rung, and
-- the price is that one of nine grid cells belongs to it now, on whichever body is holding it, until
-- somebody walks into the Cathedral and pays eighty gold or gives up the piece for two trips. A player
-- who buys this and then wants the cell back has to use the rite -- which is the best possible way to
-- learn what the rite is, because they chose the curse and they know exactly what it cost.
--
-- IT IS THE SHAMAN'S SHELF SAYING WHAT THE SHAMAN'S SHELF IS. The discipline binds spirits into things
-- and makes them stay (data/classes/shaman.lua). This is that sentence with the caster's own hand in it:
-- he did not bind a spirit into somebody else's sword, he bound one into his own cord so that nothing
-- could take it off him -- and the game charges him for it on exactly the same terms it charges a player
-- who stepped on a hex stone.
return {
    name = "The Hexbinder's Cord",
    description = "+3 magic damage and +2 magic defense, and it can never be taken off.",
    flavor = "He tied it on once. Whatever he tied on with it agreed to the once and not to the off.",
    sprite = "assets/items/hexbinders_cord.png",
    type = "utility",
    tags = { "charm", "dark" },
    class = "shaman",
    -- FOUND IN THE RIFT, NOT DEALT OVER A COUNTER (docs/shelf.md). Since the recut only abilities,
    -- consumables and a house's opening weapon carry a `price` at all; everything else is found,
    -- and a counter stocks it only once the company has carried one out.
    unlockLevel = 9,
    -- BORN BOUND (models/item.lua's instantiate copies this straight through). The Clinging Hand costs
    -- nothing but the cell, which is the only hex on the ladder a counter has any business selling.
    curse = "curse_the_clinging_hand",
    bonus = { magicDamage = 3, magicDefense = 2 },
}
