-- THE WOOD BEHIND HER: the White Wolf's standing, written as an item because that is where traits live.
--
-- The alpha's lead reaches two tiles and you can walk out of it (utility_pack_presence.lua). Hers
-- reaches every wolf in the fight, wherever they are standing, and there is nothing to walk out of. A
-- god does not have a radius -- that is the whole difference between the two animals, said in one
-- number, and it is why the only answers to her aura are killing the wolves or killing her.
--
-- THE LARGEST LEAD APPLIES, NEVER THE SUM (trait_runs_with_the_pack.lua does the reading). Her howl
-- calls alphas onto a board she is already standing on, so a wolf inside both auras is the ordinary
-- case here rather than the corner one. Summed, this fight's damage would come out of however many
-- leads happened to be alive instead of out of a figure anybody chose. Taking the best keeps the fight
-- tunable off two authored numbers, and keeps the readout honest: a wolf is running with a lead or it
-- is not, and hers is the one that is always on.
--
-- 99 RATHER THAN A FLAG, and that is deliberate cowardice about scope. "Unbounded" would mean a second
-- branch in the reader, tested nowhere, existing for one body; a reach larger than any board this game
-- builds is the same behaviour with no new code path. If an arena ever exceeds it, the aura is the
-- least of that arena's problems.
--
-- `bound = true` (models/item.lua): unstealable, nailed to her grid -- a rogue cannot lift the wood off
-- her. `class = "creature"` and no price, so the drop pool cannot mint it and her fight is never handed
-- to the player as-is (docs/bestiary.md). What she drops is a rebuild at a reach somebody could earn
-- (data/items/utility/utility_the_wood_remembers.lua).
return {
    name = "The Wood Behind Her",
    description = "Increase damage by 5 for every wolf in the fight, while she stands.",
    flavor = "The pack is not following her. It is doing what she is already doing, a half-second later.",
    sprite = "assets/items/the_wood_behind_her.png",
    type = "utility",
    class = "creature",
    tags = { "signature", "beast" },
    bound = true,
    noSteal = true,
    traits = { "trait_pack_lead" },
    traitParams = {
        packReach = 99, -- the board (see the header)
        packDamage = 5, -- worth more than an alpha's, and it never lapses
    },
}
