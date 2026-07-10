-- The item form of the Knight's Oathward: a warden's plate that binds its wearer to the same vow --
-- soak the first blow each turn on an adjacent ally. Any character who wears it becomes a guardian.
-- A knight-class chestpiece, sold at the Bastion; solid steel, so it is a shield in both senses.
return {
    name = "Warden's Oath",
    description = "Sworn plate. The first hit each turn on an adjacent ally is taken by you instead.",
    sprite = "assets/items/wardens_oath.png",
    type = "armor",
    tags = { "plate" },
    class = "knight",
    price = 280,
    repRank = 3,
    traits = { "oathward" },
    bonus = { defense = 6, movement = -1 },
    resist = { physical = 2 },
}
