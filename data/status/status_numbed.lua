-- NUMBED: Sloth's Numb, as a badge (data/traits/trait_numb.lua). Every stamina or mana cost the bearer pays
-- is 1 higher per stack (Status.costAdd), up to three. Effort gets expensive; a free swing stays free.
return {
    name = "Numbed",
    abbr = "Numb",
    description = "Numbed: every stamina or mana cost is 1 higher per stack.",
    color = { 0.690, 0.780, 0.840 },
    duration = 15,
    debuff = true,
    magnitude = 1,
    stacks = 3,
    costAdd = 1,
}
