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
    price = 80, -- no magnitude to scale, so it never forges past the plain thing it is
}
