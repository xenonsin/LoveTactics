-- The Gaff Line: a weighted hook on a length of chain, thrown down a lane. Whatever it catches comes
-- back with it, hurt, and lands next to the thrower.
--
-- Pull already exists on the knight's shelf, and this is deliberately not that spell. Pull is clean
-- displacement -- it takes a body out of position and does nothing else. The Gaff LANDS FIRST: the
-- hook does real damage on the way in, and the target arrives already wounded, already adjacent,
-- already in the middle of the alchemist's own gas and bombs and barrels.
--
-- Which is the whole point of putting it on the envy shelf. The alchemist has the best ground in the
-- game and no way at all to make anybody stand on it. Every hazard, coating, keg and gas cloud this
-- class owns is worth precisely nothing against an enemy that declines to walk into it -- and the
-- enemy AI, which paths around hostile ground, always declines. The Gaff is the answer: you do not
-- persuade them onto the fire, you fetch them.
--
-- It drags them across everything in between (fx.pull walks its victim one tile at a time, springing
-- every trap and hazard on the way), so a lane the alchemist has already prepared is worth far more
-- than the hook's own damage. Thrown down a corridor of your own caltrops and quicksand, this is the
-- highest-damage single action the class has.
--
-- ADJACENCY: any `weapon` beside it -- the hook has to be swung off something. Loose on purpose: what
-- the alchemist is holding is their business, and this spell has an opinion about the lane rather than
-- about the blade.
return {
    name = "The Gaff Line",
    description = "Hooks a distant foe, wounds it, and hauls it in across everything between.",
    flavor = "The Crucible's answer to a man who will not come to the door.",
    sprite = "assets/items/ability_gaff_line.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "alchemist",
    price = 320,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 5,
        minRange = 2, -- pointless on somebody already beside you
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 9 },
        damage = { 8, 9, 10, 10, 11, 12, 13, 14, 14, 15, 16 },
        requiresAdjacent = { type = "weapon" },
        effect = function(fx)
            -- Bite first, haul second. The order matters for a reason the pure Pull never has to think
            -- about: a hook that killed its target would have nothing left to drag, and dealing the
            -- damage first means a lethal gaff simply leaves a corpse where it stood -- which is the
            -- honest outcome, and one the player can see coming off the damage preview.
            fx.damage(fx.target)
            if not fx.target.alive then return end
            fx.pull(fx.target)
        end,
    },
}
