-- Updraft: a column of air that takes one body off the board entirely for a while. It cannot act, it
-- cannot answer, it cannot move -- and nothing can touch it either (data/status/status_suspended.lua).
--
-- THE ONLY CONTROL IN THE GAME THAT PROTECTS WHAT IT LANDS ON, and everything interesting about it
-- follows from that. A stun sets a target up to be killed. A suspension removes it from the fight in
-- both directions, so it is a spell with no obvious side.
--
--   * On an ENEMY it is area denial with a sting in it: their heaviest piece is gone for two turns,
--     and so is your archers' ability to shoot it. Cast it on the one you cannot kill, never on the
--     one you are killing -- suspending a foe at low health is how you lose a kill you had earned.
--   * On an ALLY it is the cheapest rescue in the catalog. Nothing reaches them while they hang; a
--     focused priest, a dying knight, a companion three enemies have converged on -- all of them can
--     be lifted out and set back down after the enemy has spent its turns on nothing. It costs them
--     their own next turn, which is a real price and usually the right one to pay.
--
-- There is no configuration in which it is simply good, which is the whole reason it is worth a slot.
-- Every other control on this shelf answers "how do I stop that", and this one answers "how do I make
-- the next two turns not count" -- for whichever side needs that more.
--
-- ADJACENCY: an `arcane` neighbour. Nothing elemental about lifting a body, so no coating and no
-- element charm can sharpen it; it competes for the same craft slot the Breath and the Hour want, and
-- a mage cannot carry all three well.
return {
    name = "Updraft",
    description = "Lifts one body out of the fight: it cannot act, answer, move, or be targeted.",
    flavor = "A perfectly reversible working. The Arcanum notes that most objections concern the interval.",
    sprite = "assets/items/ability_updraft.png",
    type = "ability",
    tags = { "arcane", "magical" },
    class = "mage",
    price = 340,
    repRank = 3,
    activeAbility = {
        -- A TILE target rather than "enemy" or "ally", and that is the whole point: neither of those
        -- words describes what this spell is for. Aimed at a cell, it lifts whoever is standing there
        -- -- friend, foe, or the caster -- and the player decides each turn which of the two readings
        -- above they are buying. An "enemy" target would have made it a control spell that happens to
        -- protect; an "ally" target would have made it a rescue that happens to deny.
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 12 },
        support = true, -- it lands no damage on anybody, whichever way it is pointed
        requiresAdjacent = { tag = "arcane" },
        effect = function(fx)
            local lifted = fx.unitAt(fx.tx, fx.ty)
            if not lifted then return end
            fx.applyStatus(lifted, "status_suspended", { duration = 10 + fx.level })
        end,
    },
}
