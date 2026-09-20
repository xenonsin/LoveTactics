-- PACK PRESENCE: what an Alpha Wolf is FOR.
--
-- data/encounters/encounter_wolf_pack.lua has claimed since it was written that the alpha gives that
-- fight a kill order -- "the pack is worth more with it alive, so the correct play is to reach past the
-- teeth in front of you" -- and until this file the alpha was a grunt with bigger numbers, so the claim
-- was true of nothing on the board. Wolves within two tiles of the body carrying this hit harder, and
-- they stop the instant it falls. That is the whole item.
--
-- IT IS A MARKER AND NOT AN EFFECT. `trait_pack_lead` executes nothing; the reading is done from the
-- other side by `trait_runs_with_the_pack`, which every wolf carries on its teeth. That direction is
-- forced by the engine rather than chosen: Trait.liveBonus walks the traits of the unit whose stat is
-- being read, so a passive can only ever raise the stats of its own bearer. See the trait files.
--
-- THE TWO FIGURES ARE HERE, not in the trait, because this is what an ALPHA'S lead is worth -- the
-- White Wolf's own relic grants the same marker with a reach that covers the board
-- (data/items/utility/utility_the_white_wolf.lua). One trait, two animals, two numbers, exactly the
-- split `traitParams` exists for.
--
-- A RING OF TWO IS THE COUNTERPLAY. You can stand outside it, you can pull a wolf out of it, and you
-- can kill the thing at the middle of it -- three answers, which is what separates this from her aura,
-- where the only answer is killing something.
--
-- No `class`/`price`: it is not crafted or sold, only born with, and it sits in the alpha's grid the
-- way a signature relic sits in a hero's. `noSteal` for the same reason the teeth are -- a pickpocket
-- does not lift a wolf's standing in its own pack.
return {
    name = "Pack Presence",
    description = "Increase damage by 3 for every wolf within two tiles of it.",
    flavor = "Nothing is announced. The others simply commit, and keep committing, while it is watching.",
    sprite = "assets/items/pack_presence.png",
    type = "utility",
    class = "creature",
    tags = { "beast" },
    noSteal = true,
    traits = { "trait_pack_lead" },
    traitParams = {
        packReach = 2,  -- a ring you can stand outside of
        packDamage = 3, -- what standing with an alpha is worth
    },
}
