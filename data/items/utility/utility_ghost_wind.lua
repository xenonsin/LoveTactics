-- Ghost-Wind: the Shaman's second hunter-shelf charm (hunter x mage). Everything you summon arrives
-- already Hasted.
--
-- It answers the real complaint about the reserve economy this discipline borrowed from the Arcanum: a
-- spirit locks away a fifth of your maximum mana for as long as it stands, and then spends its first
-- existence walking toward the fight. Hasted on arrival is the difference between a summon that takes
-- part in the turn you paid for it and one that takes part in the next.
--
-- It replaced a Spirit Walk -- an ability that swapped the shaman with a spirit anywhere on the field --
-- and the reason is worth recording: that was the plan's third teleport, and the author had already
-- turned down a blink on the Vanguard. A discipline whose spirits arrive fast does not need one.
--
-- Generic, like the Mask beside it: a wolf, a construct or a raised corpse all catch the wind.
return {
    name = "Ghost-Wind",
    description = "Everything you summon arrives Hasted.",
    flavor = "It does not carry them, exactly. It agrees with them about where they were going.",
    sprite = "assets/items/utility_ghost_wind.png",
    type = "utility",
    tags = { "charm", "spirit" },
    class = "hunter",
    discipline = "shaman",
    price = 345,
    unlockQuests = 2,
    traits = { "trait_ghost_wind" },
}
