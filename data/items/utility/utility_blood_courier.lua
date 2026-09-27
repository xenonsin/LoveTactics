-- BLOOD COURIER: the Familiar's organ -- its wings (`flying`) and its errand (trait_blood_courier). What it drinks
-- goes to the nearest vampire. Wrath's vampires, 2026-09-26.
return {
    name = "Blood Courier",
    description = "Flies. What it drinks goes to the nearest vampire, as if that vampire had bitten.",
    flavor = "Leather wings, a warm belly, and a mouth that empties itself into its master.",
    sprite = "assets/items/utility_blood_courier.png",
    type = "utility",
    tags = { "natural", "flying" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_blood_courier" },
}
