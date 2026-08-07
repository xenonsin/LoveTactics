-- Vigil Beads: the mage half of the Theurge (mage x priest). Your channels cannot be interrupted.
--
-- Exactly what the author asked for and nothing else. The draft bundled this with a speed bonus and the
-- bundle was cut, which was right: seven statuses in the game shatter a wind-up -- Stun, Freeze, Sleep,
-- Silence, Polymorph, Suspension, and a hard shove -- and being proof against all of them at once is
-- not a modest effect that needs propping up, it is the entire purchase.
--
-- It is the item the discipline could not exist without. A channelled miracle is a bet: you spend the
-- turn, you announce the spell, and the enemy gets a whole initiative slot to decide whether to let you
-- have it. Against anything that can Stun, the honest answer is that they will not, and every channel
-- on the shelf was unplayable against half the bestiary. This does not make the bet cheaper -- the
-- wind-up still costs the turn -- it makes it a bet you are allowed to win.
--
-- Note what it does NOT do: the control still lands. A theurge wearing these is stunned, shoved down
-- the initiative order, and finishes the spell anyway. What it declines is the cancellation, never the
-- status -- the same line weapon_kingsfall draws, moved from the weapon to the caster.
return {
    name = "Vigil Beads",
    description = "Channelled spells cannot be interrupted, by anything.",
    flavor = "One bead per interruption she has already declined. It is not a short string.",
    sprite = "assets/items/utility_vigil_beads.png",
    type = "utility",
    tags = { "charm", "holy" },
    class = "mage",
    discipline = "theurge",
    price = 380,
    unlockQuests = 5,
    traits = { "trait_vigil_beads" },
}
