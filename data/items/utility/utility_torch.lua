return {
    name = "Torch",
    description = "Extends the party's vision on the overworld.",
    flavor = "The oldest answer to the dark, and still the only one anybody trusts.",
    sprite = "assets/items/torch.png",
    type = "utility", -- no active ability -> no speed, ignored by combat initiative
    visionRadius = 3, -- overworld fog-of-war reveal radius while a party member carries it
    -- Classless on purpose: fire in the dark is nobody's craft. That is what puts it on the general
    -- store's shelf (a priced item with no class -> the Market; see models/vendor.lua). No magnitude
    -- to scale, so it never forges past the plain thing it is.
    price = 20,
}
