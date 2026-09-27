-- UNMOVED: the Oni Greatblade's organ. Approved 2026-09-26 ("The Oni of Wrath"): "it can't be Stunned,
-- knocked back or slowed."
--
-- Stun, Cripple and Torpid are warded off at the door (`statusImmunity`, the innate-immunity field), and the
-- trait's `unmoved` flag makes Status.blocksForcedMove answer yes, so no shove, pull or throw moves her.
-- Bound and unstealable: what she is, not what she carries.
return {
    name = "Unmoved",
    description = "Cannot be Stunned, Crippled or made Torpid, and cannot be moved.",
    flavor = "Plans are for people who expect to be stopped.",
    sprite = "assets/items/utility_unmoved.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    statusImmunity = { "status_stun", "status_cripple", "status_torpid" },
    traits = { "trait_unmoved" },
}
