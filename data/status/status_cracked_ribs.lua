-- Cracked Ribs: the Defense half of data/injuries/injury_cracked_ribs.lua, and the only badge in the
-- injury set that makes the next fall likelier rather than the next swing smaller.
--
-- THREE POINTS AGAINST A 5-14 BAND. The roster's authored Defense sits between a mage's 5 and a
-- sentinel's 14, so this is a fifth to a half of a body's armor -- a real bite on a front-liner and
-- nearly the whole of a caster's, which is the right shape: the caster was not standing there anyway,
-- and the front-liner is the body the player keeps choosing to field hurt.
--
-- Magic Defense is deliberately untouched. Ribs are what a hammer breaks, and leaving the magical side
-- whole gives the injury a shape a player can play around -- keep that body out of the melee line --
-- rather than a flat tax on being hit by anything at all.
--
-- See data/status/status_shattered_leg.lua for why `debuff = false`.
return {
    name = "Cracked Ribs",
    abbr = "Ribs",
    description = "Cracked Ribs: takes more from every blow.",
    color = { 0.478, 0.353, 0.400 }, -- badge tint (bruise)
    duration = 9999,
    debuff = false,
    statBonus = { defense = -3 },
}
