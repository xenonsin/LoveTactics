-- The Charnel Reliquary: a bone box of grave-ash worn at the belt, carrying the Death's Dividend trait
-- (data/traits/trait_deaths_dividend.lua). While it is in the grid, every real body that drops within
-- three tiles of its bearer leaves them a little more dangerous -- a standing lift to Magic Damage that
-- stacks with each death and holds for the rest of the fight.
--
-- The non-active half of the Necromancer's shelf: where Raise Dead, Corpse Burst and Toll the Knell are
-- all casts, this is the charm that reads the killing floor and grows on it. It does nothing on turn one
-- of a clean fight and everything in the tenth turn of a slaughter, which is the discipline's whole
-- posture said as a passive -- the longer death has been in the room, the stronger its student.
--
-- The cost is the grid slot, the balance of any charm: no stats of its own, no reflex in a fight where
-- nobody dies near you. Carrying one is a bet that bodies will fall and that you will be standing over
-- them when they do -- which, for a Necromancer, is not much of a gamble.
return {
    name = "Charnel Reliquary",
    description = "Each body that falls near you raises your Magic Damage this battle.",
    flavor = "Every grave is a lesson, the Arcanum notes, and it charges tuition for the ones it keeps.",
    sprite = "assets/items/utility_charnel_reliquary.png",
    type = "utility",
    tags = { "charm" },
    class = "mage",
    discipline = "necromancer", -- deeper cut of the shelf: buyable only once the necromancer gate is cleared
    price = 300,
    unlockQuests = 6,
    traits = { "trait_deaths_dividend" },
}
