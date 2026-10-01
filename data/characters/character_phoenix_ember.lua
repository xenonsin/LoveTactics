-- A PHOENIX'S EMBER: what a felled Phoenix burns down to (trait_never_repents; "Pride's Bestiary", 2026-09-30).
-- An object that stands outside the turn order (`timeless`), as the Dragon Egg and the scarab's egg are, with
-- a three-turn clock on it (status_rekindling): when the clock runs out it rises again as the Phoenix, whole.
--
-- It counts on the Phoenix's side, so a kill-all is not won while one stands, and BREAKING IT is the only end
-- the fight has. It does not grow with the floor (`scaling = false`, the egg's argument): "break it in the
-- three turns" is the whole of the counterplay, and a levelled Ember that shrugged a company's turn would take
-- it away. Built to fall to two or three blows, not one -- it is a race, not a formality.
return {
    name = "Ember",
    race = "object",
    tier = 0,
    timeless = true,
    scaling = false,
    unarmed = false,
    sprite = "assets/chars/phoenix_ember.png",
    stats = {
        health = 45, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0,
        defense = 5, magicDefense = 5,
        movement = 0, -- it does not move
        speed = 0,    -- it takes no turns
        skill = 0, luck = 0,
    },
    startingItems = {},
}
