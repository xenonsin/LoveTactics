-- MAN-EATER: the Manticore's appetite (trait_man_eater). A foe that goes down beside it is eaten -- no
-- revive this battle -- and its Tail Volley is ready again. Creature kit only; it has no drop, because
-- the one thing Gluttony will not hand a company is the habit of eating its own.
return {
    name = "Man-eater",
    description = "A foe that falls beside it is eaten: it cannot be revived this battle, and Tail Volley is ready again.",
    flavor = "It leaves nothing. That is the one thing every account of it agrees on.",
    sprite = "assets/items/utility_man_eater.png",
    type = "utility",
    class = "creature",
    tags = { "beast" },
    noSteal = true,
    traits = { "trait_man_eater" },
}
