-- RUST HIDE: the Rust Mite's shell. Any weapon that strikes it in melee rusts (trait_rust_hide,
-- status_tarnished). A natural piece: creature kit, no price, noSteal.
return {
    name = "Rust Hide",
    description = "Any weapon that strikes it in melee is Tarnished.",
    flavor = "It is not armoured in iron. It is armoured in what iron turns into.",
    sprite = "assets/items/utility_rust_hide.png",
    type = "utility",
    class = "creature",
    tags = { "beast" },
    noSteal = true,
    traits = { "trait_rust_hide" },
}
