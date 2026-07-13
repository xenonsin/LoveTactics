-- Iron Fist: hands hardened past a weapon's need. A passive "fist" charm that pours flat damage into
-- the bearer's bare-handed strike (`unarmedBonus.damage`, folded onto the hidden unarmed weapon in
-- models/combat.lua). It does nothing for a crafted blade -- only the fist. Stack it with the other
-- fist charms (Shadow, Swift, Drunken) to build a monk whose punch outclasses a sword.
return {
    name = "Iron Fist",
    description = "Your bare-handed strike hits markedly harder (+4 Power). Does nothing for a weapon.",
    sprite = "assets/items/iron_fist.png",
    type = "utility",
    tags = { "fist" },
    class = "priest",
    price = 180,
    repRank = 2,
    unarmedBonus = { damage = { 4, 4, 5, 5, 6, 6, 6, 7, 7, 8, 8 } },
}
