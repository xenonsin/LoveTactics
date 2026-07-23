-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- THE ONLY ARMOR IN THE GAME THAT ANSWERS A BOW. Every other reflex on the rack -- thorns, a parry, a
-- shield bash, the Whirlplate -- requires the attacker to have come within arm's reach, which means
-- the correct way to fight all of them has always been to shoot. trait_slipstep does not care about
-- range: struck from anywhere, the wearer appears BESIDE the attacker and cuts.
--
-- Which is why it is on the greed shelf rather than the wrath one. It is not retaliation, it is
-- arrival: the archer's own shot is the thing that delivers a dagger to the archer. weapon_slipknife
-- carries the same reflex off a blade; a rogue holding both answers twice and pays the escalating
-- answer price twice (Trait.answerCost), which drains them in about two rounds. That is the cap, and
-- it is a stamina bar rather than a hidden timer.
--
-- The failure case is loud and worth stating: the blink puts the wearer in the middle of whatever the
-- attacker was standing in. Shot from inside a fire, you end up in the fire.
return {
    name = "Slipstep Leathers",
    description = "When struck from any range, appear beside the attacker for a swing's stamina and cut.",
    flavor = "The Undercroft's answer to archers, which for a long time was to employ them instead.",
    sprite = "assets/items/armor_slipstep_leathers.png",
    type = "armor",
    tags = { "leather" },
    class = "rogue",
    traits = { "trait_slipstep" },
    bonus = { defense = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 } },
    resist = { physical = { 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3 } },
}
