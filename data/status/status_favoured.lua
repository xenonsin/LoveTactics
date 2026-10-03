-- FAVOURED: the Kinslayer's counter (models/kinslayer.lua; "Envy's Bestiary", row kn_body). Worn by the body of
-- the company healed or blessed most this fight; the number is that count, one for every heal and one for every
-- blessing. He hunts whoever wears it, and it moves the moment somebody else is tended more.
--
-- UNDISPELLABLE: it is a fact about the fight, not a blessing (Combat.dispellableOn passes it over, so it never
-- makes its bearer Fairest and no mote strips it), and not a debuff, so no Cure takes it off either.
return {
    name = "Favoured",
    abbr = "Fav",
    description = "The Kinslayer hunts this body. The count is heals and blessings taken this fight.",
    color = { 0.70, 0.22, 0.20 }, -- badge tint (old blood)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
}
