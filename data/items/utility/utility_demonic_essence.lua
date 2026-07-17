-- Not gear -- the stuff a demon is made of. It carries a NEGATIVE holy resist, which
-- Combat.mitigatedDamage sums like any other resist: a negative value amplifies the hit, so holy
-- damage lands the harder for it. This is how "Demon Bane cuts the damned tenfold" is expressed in
-- data, with no engine change (resist has always accepted negatives). Bound to the body that owns it:
-- it can't be stolen off a demon, and a copy of one never carries its maker's flesh.
return {
    name = "Demonic Essence",
    description = "Holy damage bites far deeper.",
    flavor = "Not gear at all -- the stuff a demon is made of, and it comes off nothing living.",
    sprite = "assets/items/demonic_essence.png",
    type = "utility",
    tags = { "demon" },
    noSteal = true,
    noCopy = true,
    resist = { holy = -8 }, -- negative: takes extra damage from holy-tagged hits
}
