-- A mace, so it shoves (docs/weapons.md) -- and this is the family's argument taken to its end. Four
-- tiles of travel where the iron mace buys two, and a damage curve so low that the shove is not merely
-- the point, it is the entire weapon.
--
-- The knight shelf's top rung alongside the Gathering Bell, and the two are the same question answered
-- in opposite directions: one fetches a body, this one removes it. Four tiles is most of a small arena.
-- It takes a charging champion out of the fight for the turns it costs him to walk back, drops a caster
-- into your archer's band, or -- the reason to forge it -- puts something into a fire, a quicksand, a
-- spike trap or a Stillness that somebody else laid four tiles ago.
--
-- What it does NOT do is kill anything, ever. That is deliberate and it is the whole design: a mace that
-- displaced this far AND hit for a mace's damage would simply be the best knight weapon in the game.
-- What it sells is the board, and the party has to be built to collect on it.
--
-- The collision still pays -- more travel robbed means more impact -- so against a wall this is quietly
-- the hardest-hitting mace on the shelf. In the open field it is a shove and an apology.
return {
    name = "The Long Fall",
    description = "Drives the target four tiles back. Deals almost nothing -- what it sells is where they land.",
    flavor = "The Bastion does not teach it as a weapon. It is filed under groundskeeping.",
    sprite = "assets/items/long_fall.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "melee" },
    hands = 2, -- a two-handed sweep: four tiles of travel is a whole-body swing
    class = "knight",
    price = 700,
    repRank = 4,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        -- A third of an iron mace's, and it should look wrong on the tooltip. The number is not the sale.
        damage = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7 },
        effect = function(fx)
            -- The collision is priced off the swing's own magnitude as every mace's is, so a foe pinned
            -- against a wall still eats the whole of what the travel was worth -- which, at four tiles
            -- robbed, is a great deal more than this weapon's damage curve suggests.
            fx.damage(fx.target, { knockback = { distance = 4, amount = fx.amount } })
        end,
    },
}
