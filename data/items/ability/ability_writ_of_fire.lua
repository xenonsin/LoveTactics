-- A Writ of Fire: the mage burns a mark into a tile anywhere on the board, and the mark comes due a
-- turn later, very hard, on whatever is standing there.
--
-- THE FIRST DELAYED STRIKE. Every other spell in this catalog resolves where it is aimed, at the
-- moment it is aimed -- a channel makes the caster wait, but the blow still lands on whoever is there
-- when it does. A writ inverts that: it lands where you SAID, on a beat you can count, and the
-- question is entirely whether you can make somebody be there.
--
-- Which turns the party's whole control kit into a delivery system. A root, a shove, a wall, a duel, a
-- grasping hollow -- none of those did damage, and all of them now do this much damage, a turn later,
-- if the mage was reading the board when they were cast. Nothing else on the pride shelf rewards
-- planning at that range.
--
-- The range is the other half. It reaches across the whole field with no line of sight required (there
-- is nothing to see -- the mage is writing on the ground, not throwing anything), so a writ can be laid
-- on the tile the enemy healer is about to retreat to, or on the doorway reinforcements walk in
-- through. Aiming it at a body that is currently standing still is the beginner's version and mostly
-- misses; the enemy AI reads the burning mark as hostile ground and walks off it.
--
-- ADJACENCY: a `fire` item beside it. The writ is fire, and unlike the two arcane spells above it CAN
-- borrow -- a Fire Stone next door feeds its tags into the blast exactly as it feeds any other fire
-- cast. Which is the trade the grid asks for: the fire slot buys reach and a bigger burn, and it is
-- the same slot the emberwand and the flask both want.
return {
    name = "Writ of Fire",
    description = "Burns a mark on any tile; a turn later it takes everything standing there.",
    flavor = "The Arcanum files it, seals it, and lets the ground carry out the sentence.",
    sprite = "assets/items/ability_writ_of_fire.png",
    type = "ability",
    tags = { "fire", "magical" },
    class = "mage",
    price = 380,
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        -- No `requiresSight`: the mage is writing on the ground rather than throwing anything at it,
        -- and the whole point of the spell is that it reaches the tile nobody is standing on yet.
        range = 9,
        speed = 4,
        cost = { stat = "mana", amount = 14 },
        support = true, -- it lands nothing on the turn it is cast; the damage row belongs to the mark
        requiresAdjacent = { tag = "fire" },
        effect = function(fx)
            -- Everything about this spell is on the hazard, including the damage: the mark is the
            -- weapon, and the cast is only the writing of it. A forged writ burns hotter (base 24, +3
            -- per level) but never sooner and never wider -- an upgrade should not buy back the tell.
            fx.placeHazard(fx.tx, fx.ty, "hazard_writ", { amount = 24 + 3 * fx.level })
        end,
    },
}
