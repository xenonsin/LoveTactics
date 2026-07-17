-- Shield Bash: a passive knack that turns a braced shield into a weapon. It grants the Shield Bash
-- trait (data/traits/shield_bash.lua): while the bearer is Defending and a foe lands a melee blow, the
-- bearer slams its shield into the attacker and stuns it, then the move recharges. It only arms if a
-- `shield`-tagged item (a Buckler, an Oathkeeper Shield) sits adjacent to it in the 3x3 grid -- you
-- need a shield to bash with. Put it next to your shield and take the Defend stance to make it live.
return {
    name = "Shield Bash",
    description = "While Defending, melee attackers are Stunned. Needs a shield adjacent in the grid.",
    flavor = "The Bastion's second lesson: a shield is only patient until it is not.",
    sprite = "assets/items/shield_bash.png",
    type = "utility",
    tags = { "technique" },
    class = "knight",
    price = 240,
    repRank = 2,
    traits = { "trait_shield_bash" },
}
