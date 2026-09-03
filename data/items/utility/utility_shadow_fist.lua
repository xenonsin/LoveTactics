-- Shadow Fist: a strike that reaches farther than an arm should. A passive "fist" charm that extends
-- the range of the bearer's bare-handed strike by one tile (`unarmedBonus.range`, added to the unarmed
-- ability's reach in Combat.abilityRange) -- so the fist can jab a foe a tile away. Only the fist is
-- lengthened, never a crafted weapon. Stacks with the other fist charms.

return {
    name = "Shadow Fist",
    description = "Bare-handed strikes reach one tile farther. Does nothing for a weapon.",
    flavor = "An arm does not do that. The Cathedral's monks decline to discuss which part is the arm.",
    sprite = "assets/items/shadow_fist.png",
    type = "utility",
    tags = { "fist" },
    class = "monk", -- deeper cut of the shelf: buyable only once the monk gate is cleared
    price = 245,
    unlockQuests = 2,
    unarmedBonus = { range = { 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2 } },
    bonus = { movement = 1 },
}
