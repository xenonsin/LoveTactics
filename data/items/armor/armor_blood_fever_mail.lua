-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Every body that hits the ground -- either side, anyone's kill, including the wearer's own allies --
-- permanently raises the wearer's Damage for the rest of the battle (trait_blood_fever).
--
-- The only scaling item in the catalog that counts the WHOLE BOARD rather than the wearer's own work,
-- which makes it the first armour whose value is set by the fight's shape instead of the wearer's
-- build. A long grinding battle against a horde ends with a fighter swinging for numbers nothing else
-- in the game produces; a short one against three elites ends with a mediocre hauberk.
--
-- Counting the party's dead is not an oversight and must not be tidied away. Wrath does not
-- distinguish -- that is the entire characterization of the sin in docs/story.md -- and a version that
-- politely tallied only enemies would be a fighter item about bookkeeping rather than about appetite.
-- It also produces the game's ugliest good decision: a losing fight makes the survivor stronger.
--
-- The mail itself is light for the shelf, deliberately. It is a payout curve, not a wall, and a wearer
-- who survives long enough to collect the whole curve should have done it by killing.
--
-- utility_butchers_tally grants the same rule from a cell.
return {
    name = "Blood-Fever Mail",
    description = "Every body that falls, on either side, permanently raises your Damage this battle.",
    flavor = "The Colosseum counts the house by the mail's own reckoning and has never found it generous.",
    sprite = "assets/items/armor_blood_fever_mail.png",
    type = "armor",
    tags = { "plate" },
    class = "fighter",
    traits = { "trait_blood_fever" },
    bonus = { defense = { 5, 5, 6, 7, 7, 8, 8, 9, 10, 10, 11 }, movement = -1 },
    resist = { slash = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 } },
}
