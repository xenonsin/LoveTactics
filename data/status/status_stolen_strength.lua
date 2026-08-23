-- Stolen Strength: somebody else's arm, worn for a while. A flat bonus to the bearer's Damage, routed
-- through `magnitudeStat` exactly as Lent Guard routes its borrowed defense (Status.statBonus).
--
-- The other half of status_sapped, and the two are only ever applied together by
-- data/items/ability/ability_sap.lua: the victim loses this much Damage, the thief gains this much, for
-- the same span. Nothing is created -- which is the whole sentence the Undercroft is making, and the
-- reason the deliverer caps its theft at what the victim's arm actually holds.
--
-- It moves `damage` and not `magicDamage`, for the reason Empowered gives: this is a blow to the arm
-- and what it takes is what the arm was for. A rogue who steals a swordsman's strength does not
-- suddenly cast better, and a mage's arm was never worth robbing in the first place.
--
-- The magnitude is always handed in by the deliverer; the +4 below is the fallback for a source that
-- names none. A refresh REPLACES it (Status.apply), so a thief working down a line wears the last arm
-- it took rather than all of them at once -- you can only stand in one man's strength at a time.
--
-- Not a debuff and not resistible: it is already stolen. Nothing here argues with the recipient.
return {
    name = "Stolen Strength",
    abbr = "Stln",
    description = "Wearing somebody else's strength: Damage is raised while it holds.",
    color = { 0.811, 0.700, 0.335 }, -- badge tint (coin gold -- greed's colour, as the Struck Ledger wears it)
    duration = 12,
    magnitude = 4,
    magnitudeStat = "damage",
}
