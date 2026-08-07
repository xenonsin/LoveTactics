-- Dampening Oath: the standing rule of the Spellbreaker's charm. Enemy workings cast within three tiles
-- of the bearer cost double mana.
--
-- A flag (Trait.flag) read in Combat.spendCost, the one path every cast in the game pays through.
--
-- A TAX, not a denial, and that distinction is the whole shelf. Four active anti-magic items were drafted
-- for this discipline across two review rounds and every one was turned down as too punishing -- an
-- interrupt takes somebody's turn away, and the fun of playing against a caster is not "you may not".
-- This one never refuses anything: the enemy mage casts exactly what it wanted to, and discovers
-- afterwards that it can afford one fewer of them. What the spellbreaker has bought is that the other
-- side runs dry first.
--
-- Applied at the SPEND rather than at the affordability check, deliberately. A caster who could just
-- afford a spell is allowed to commit to it and then finds the pool emptied -- being taxed into nothing
-- is the threat, and warning them at the button would defuse it.
return {
    name = "Dampening Oath",
    description = "Enemy spells cast within three tiles of you cost double mana.",
    dampensNearbyCasts = true,
}
