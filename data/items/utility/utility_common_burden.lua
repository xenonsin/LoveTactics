-- THE COMMON BURDEN: the counting charm that reads the whole company rather than one grid
-- (data/traits/trait_common_burden.lua, docs/curses.md).
--
-- EVERY OTHER COUNTING ITEM ASKS ONE BODY. This asks the line, which makes a cursed PARTY a build --
-- four bodies carrying one hex apiece pay it exactly as well as one body carrying four, and the spread
-- version is far easier to keep alive. A company that has been walking the deep floors and taking what
-- the ground gives it is, without ever deciding to, running this charm's build.
--
-- ARMOUR RATHER THAN DAMAGE, so it does not compete with The Gathered Weight for the same job in the
-- same cell. One says the hexed body hits harder; this says the hexed COMPANY is harder to break, and a
-- player carrying both is being paid twice for one decision -- which is fine, because the decision was
-- to let curses accumulate and the bill for that arrives at the Cathedral either way.
return {
    name = "The Common Burden",
    description = "+1 defense and +1 magic defense to the whole line per hex the company carries.",
    flavor = "Shared out, it is bearable. That is not the same as light.",
    sprite = "assets/items/common_burden.png",
    type = "utility",
    tags = { "charm", "dark", "morale" },
    class = "shaman",
    unlockLevel = 4,
    traits = { "trait_common_burden" },
}
