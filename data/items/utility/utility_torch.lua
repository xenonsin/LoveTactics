return {
    name = "Torch",
    description = "Extends the party's vision on the overworld.",
    flavor = "The oldest answer to the dark, and still the only one anybody trusts.",
    sprite = "assets/items/torch.png",
    type = "utility", -- no active ability -> no speed, ignored by combat initiative
    visionRadius = 3, -- overworld fog-of-war reveal radius while a party member carries it
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
