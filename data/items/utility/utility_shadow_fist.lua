-- Shadow Fist: a strike that reaches farther than an arm should. A passive "fist" charm that extends
-- the range of the bearer's bare-handed strike by one tile (`unarmedBonus.range`, added to the unarmed
-- ability's reach in Combat.abilityRange) -- so the fist can jab a foe a tile away. Only the fist is
-- lengthened, never a crafted weapon. Stacks with the other fist charms.
return {
    name = "Shadow Fist",
    description = "Your bare-handed strike reaches one tile farther. Does nothing for a weapon.",
    flavor = "An arm does not do that. The Cathedral's monks decline to discuss which part is the arm.",
    sprite = "assets/items/shadow_fist.png",
    type = "utility",
    tags = { "fist" },
    class = "priest",
    price = 260,
    repRank = 3,
    unarmedBonus = { range = { 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2 } },
}
