return {
    name = "Torch",
    description = "Reveals one more place on the overworld, and keeps your sight in the dark.",
    flavor = "The oldest answer to the dark, and still the only one anybody trusts.",
    sprite = "assets/items/torch.png",
    type = "utility", -- no active ability -> no speed, ignored by combat initiative
    -- HOW MUCH FURTHER THE COMPANY READS while anyone is carrying one: ONE STEP, and one is the whole
    -- of it. A BONUS RATHER THAN A RADIUS -- sight is a flat one step (models/player.lua's
    -- Player.VISION) and this adds to it, taking a party from "the places beside you" to "the places
    -- beside those". It was an absolute 3 that a max() took over a base of 2, back when a cell was a
    -- TILE; a cell is a place now (models/overworld.lua), four of them to a step, and three steps would
    -- hand over a small floor from the doorway.
    --
    -- IT IS ALSO THE ANSWER TO THE DARK, which is what the flavour has always claimed and what the
    -- number never bought. The dark takes the BASE to nothing (states/game.lua's applyVision) and the
    -- bonus rides on top of it, so a company holding a light walks a darkened floor at ordinary sight
    -- while one that never bought a torch steps into each place blind.
    visionBonus = 1,
    -- The Lodge's shelf. It carries no combat keyword at all, which for once is the argument rather
    -- than against it: gluttony's whole vocabulary is SETUP -- mark the quarry, read the ground, know
    -- what is out there before it knows about you -- and a torch is the crudest instrument of that
    -- there is. It was classless while the Cafe sold groceries; the Cafe sells suppers now, and the
    -- house that hunts in the dark is the one that sells the light to do it by.
    class = "hunter",
    unlockQuests = 0, -- opening shelf: a party should be able to see on its first night out
    -- THE ONE NAMED EXCEPTION TO THE SHELF RECUT (tools/drop_tier.lua). Every other utility came off
    -- the shelf and is found in the rift; a torch is bought, because seeing in the dark is not a thing
    -- a company should have to get lucky about. It still drops at depth 1 as well, so a run that did
    -- not think to buy one is not walking blind to the bottom.
    price = 80, -- no magnitude to scale, so it never forges past the plain thing it is
    dropTier = 1,
    -- seeing further is aiming better, even on a torch
    bonus = { skill = 1 },
}
