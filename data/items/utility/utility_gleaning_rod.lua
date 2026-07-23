-- The Gleaning Rod: a plain iron shaft that drinks the leavings of other people's workings. Every
-- spell cast near it -- theirs or yours -- banks a charge, and the charges are spent all at once as a
-- bolt or as a mending (data/traits/trait_gleaning.lua).
--
-- THE STRANGEST ECONOMY ON THE SHELF, and that is the item. Every other thing in this catalog is worth
-- what the tooltip says. This is worth whatever KIND OF BATTLE the player has walked into, and they
-- find out on the second turn rather than at the shop: against four fighters it is an empty stick, and
-- against the Arcanum it is full by turn three and stays full.
--
-- Which makes it the first item that rewards reading the enemy roster rather than reading the numbers,
-- and the first one whose right answer is sometimes to leave it at home.
--
-- BOTH SIDES FEED IT, which is the mechanic and not an oversight. Gleaning off your own priest is the
-- reliable half -- you control the timing, and a party with two casters keeps the rod ticking over on
-- purpose. Gleaning off the enemy mage is the profitable half, and it has a lovely shape to it: the
-- more dangerous their casting is, the more the rod has to answer it with.
--
-- It points both ways, like the Reliquary of Tallies -- a bolt at a foe, a mending for an ally -- so
-- the same charges serve whichever the turn needs. And it EMPTIES when it fires: this is a purse, not
-- a rate, and spending it early for a small effect is a real mistake the player will make once.
return {
    name = "The Gleaning Rod",
    description = "Banks a charge from every spell cast nearby; spend them all to wound or to mend.",
    flavor = "The Arcanum considers it vulgar. It has never satisfactorily explained on what grounds.",
    sprite = "assets/items/utility_gleaning_rod.png",
    type = "utility",
    tags = { "arcane" },
    class = "mage",
    price = 380,
    repRank = 3,
    traits = { "trait_gleaning" },
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 6 }, -- cheap: the charges are the real price
        effect = function(fx)
            local body = fx.unitAt(fx.tx, fx.ty)
            if not body then return end
            local charges = fx.item.charges or 0
            if charges <= 0 then
                fx.log("action", "The rod is dry. Nothing has been worked near it.", fx.user)
                return
            end
            local weight = charges * (5 + fx.level)
            -- Spent to nothing, whatever it bought. A purse rather than a rate -- see the note above,
            -- and see the trait, which is the only thing that ever fills it.
            fx.item.charges = 0
            if body.side == fx.user.side then
                fx.heal(body, weight)
            else
                fx.damage(body, { amount = weight, tags = { "arcane", "magical" } })
            end
        end,
    },
}
