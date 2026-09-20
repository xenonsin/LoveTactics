-- THE WOOD REMEMBERS: a wolf, for as long as you carry this.
--
-- The second entry on the White Wolf's drop list. Her own standing is an aura over every wolf in the
-- fight (utility_the_wood_behind_her.lua) and it cannot be handed over -- there is no honest version of
-- "every wolf on the board obeys you" for a party that does not field wolves. So what comes off her is
-- the other half of the same sentence: she has a pack, and now so do you.
--
-- IT FIELDS ONE, FREE, AT THE FIRST BELL. `trait_wolf_companion` does the whole job and was already
-- built for Kaya's horn (utility_wolfsong_horn.lua) -- a wolf arrives beside the bearer on combat start,
-- carrying the grunt blueprint's own teeth, under no reservation at all. Free is the distinction worth
-- naming: ability_summon_wolf locks a quarter of the caster's mana away for as long as its wolf lives,
-- and ability_mothers_howl does the same. This costs a grid slot and nothing else, which is what makes
-- it worth the depth it sits at.
--
-- AND THE WOLF CARRIES THE PACK RULES. It arrives holding weapon_wolf_fangs like any other wolf, so it
-- bites twice against a much slower body, tears at prey under half health, gives ground out of every
-- exchange -- and reads `trait_runs_with_the_pack`, which means a second wolf beside it is worth
-- something. Everything the player learned from the other side of this fight now applies to a thing
-- standing next to them.
--
-- NOT KAYA'S HORN, and the difference is deliberate. Hers is `bound` and `signature` -- nailed to one
-- grid, never earned or moved -- and its real content is the Quieting Howl it charges, which roots the
-- ring around her or the wolf. This is the companion and nothing else: no root, no charge, no bond. A
-- hunter holding both fields two wolves, which is a build rather than a bug.
--
-- Class `hunter`, unpriced: it comes off her body and nowhere else, and `dropTier` is set by the
-- grading pass (`. drop-tier`) rather than chosen here.
return {
    name = "The Wood Remembers",
    description = "Starts each battle with a wolf at your side, free of any reservation.",
    flavor = "It was not given to you and you did not earn it. Something decided, and did not explain.",
    sprite = "assets/items/the_wood_remembers.png",
    type = "utility",
    tags = { "beast" },
    class = "hunter",
    dropTier = 5,
    -- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many
    -- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
    unstocked = true,
    traits = { "trait_wolf_companion" },
}
