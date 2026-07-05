return {
    name = "Torch",
    description = "Lights the way, extending the party's vision on the overworld.",
    sprite = "assets/items/torch.png",
    type = "utility", -- no active ability -> no speed, ignored by combat initiative
    visionRadius = 3, -- overworld fog-of-war reveal radius while a party member carries it
}
