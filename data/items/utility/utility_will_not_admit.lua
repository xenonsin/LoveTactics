-- WILL NOT ADMIT THE WOUND: the Elf Highborn's organ (data/characters/character_elf_highborn.lua). Approved
-- 2026-09-30 ("Pride's Bestiary"). The one elf whose Unblemished comes back: a full round without being struck and
-- it is Unblemished again (trait_will_not_admit). Bound and unstealable.
return {
    name = "Will Not Admit the Wound",
    description = "A full round without being struck makes you Unblemished again.",
    flavor = "The cut is still there under the sleeve; it simply stands as though it were not.",
    sprite = "assets/items/utility_will_not_admit.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_will_not_admit" },
}
