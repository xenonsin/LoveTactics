return {
    name = "Torch",
    description = "Extends the party's vision on the overworld.",
    flavor = "The oldest answer to the dark, and still the only one anybody trusts.",
    sprite = "assets/items/torch.png",
    type = "utility", -- no active ability -> no speed, ignored by combat initiative
    visionRadius = 3, -- overworld fog-of-war reveal radius while a party member carries it
}
