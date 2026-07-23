-- The Sealed Reliquary: a small locked case that refuses one spell aimed squarely at its bearer, and
-- then relocks itself after a while (data/status/status_sealed_ward.lua).
--
-- NOT MITIGATION, and the difference is the whole item. Every defence in this game is arithmetic --
-- armor subtracts, resist subtracts, a barrier eats a hit, a mana shield pays out of the wrong pool.
-- All of them answer a bigger number with a bigger number, which means the enemy's counterplay is
-- simply to have a bigger number. This answers a DECISION: the one spell they most wanted to land
-- simply does not happen -- its damage, its status, its shove, its summon, all of it, refused before
-- the effect ever runs (see the gate at the top of resolveCast).
--
-- Which means the counterplay is also a decision, and a good one:
--
--   * AIM SOMETHING ELSE FIRST. The seal spends itself on whatever arrives first, so a cheap fast cast
--     strips it and the real spell lands behind. Baiting it is a genuine play, and declining to bait
--     it is a genuine bluff.
--   * OR AIM AN AREA EFFECT. A blast that catches the bearer among others goes straight past the seal,
--     because a blast does not aim at anybody. Every class in this game owns one.
--
-- AND THE CASTER STILL PAID -- cost, cooldown, turn -- so a refused spell is an enemy turn deleted,
-- which is why the recharge is long and the item is not cheap.
--
-- It carries the ward from the first beat of the battle: a relic that had to be switched on would just
-- be an ability, and the point of this one is that the enemy has to plan around it before they know
-- whether it is there.
return {
    name = "The Sealed Reliquary",
    description = "Refuses one single-target spell aimed at its bearer, then relocks after a while.",
    flavor = "The Cathedral will confirm that it is empty. It will not explain why it is locked.",
    sprite = "assets/items/utility_sealed_reliquary.png",
    type = "utility",
    tags = { "holy" },
    class = "priest",
    price = 480,
    repRank = 4,
    traits = { "trait_sealed_reliquary" },
}
