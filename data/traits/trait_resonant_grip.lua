-- Resonant Grip: the standing rule of the Battlemage's charm. The bearer's weapon strikes carry the
-- element of whatever they last cast.
--
-- A flag (Trait.flag) read in Combat.dealDamage, which folds the remembered element into the strike's
-- TAG SET rather than adding a damage number. That is the whole design: a tag reaches armour `resist`,
-- the elemental interactions (a lightning blow arcing into water, a fire blow biting a Wet body) and the
-- scaling all at once, so the same clause makes a battlemage's sword situationally brilliant and
-- situationally useless, which a flat bonus never could.
--
-- Only ever a NON-magical strike. A spell has its own element; letting the memory of one Fireball
-- overwrite another would be a bug dressed as flavour.
--
-- The memory itself (`unit.lastCastElement`) is kept on every caster in the game rather than only on
-- charm-holders. It costs one field, and a charm bought three turns into a fight should not have to
-- explain why it begins empty.
return {
    name = "Resonant Grip",
    carriesLastElement = true,
}
