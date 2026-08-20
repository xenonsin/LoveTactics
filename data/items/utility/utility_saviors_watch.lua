-- The Savior's Watch: the Crusader's charm for arriving. Carries trait_saviors_watch -- damage and
-- MOVEMENT for each wounded ally within three tiles, up to three of them, read off the board as it
-- stands rather than banked when somebody got hurt.
--
-- WHY THE CRUSADER'S. Fighter x priest already sells the swing that heals (Smite), the charge that
-- ends in a blessing (Zealous Charge) and the pool that fills off healing (Reckoning). What none of
-- them answer is the actual failure mode of the discipline, which is arithmetic rather than thematic:
-- a Crusader is a heavy body, and a heavy body wearing plate walks at 3. It is forever two squares
-- short of the person it exists to reach. This is the charm that closes that gap, and it closes it
-- exactly when the gap matters -- the square arrives BECAUSE somebody is hurt.
--
-- THE MOVEMENT IS THE ITEM. The damage half is what makes it worth a cell in a fight that is going
-- well; the square is what it is for. It is also the only movement in this catalog that is granted by
-- the state of somebody else -- every other pace item in the game is a property of the wearer's own
-- boots or legs (docs/classes.md on the armor cost table, and why armour never grants a square).
-- This does not bend that rule: it is a charm, not armour, and what it sells is answered need.
--
-- Note it counts WOUNDED allies, not downed ones. A body at 0 is Incapacitated and on a countdown
-- (docs on the downed system), and paying the Crusader for corpses would make the worst turn of the
-- fight its strongest -- the same reason the trait caps at three. It pays for people you can still
-- save, which is the whole posture of the discipline.
local Curve = require("models.curve")

return {
    name = "The Savior's Watch",
    description = "Increase damage by 2 and movement by 1 per wounded ally within 3 tiles, up to 3.",
    flavor = "He never learned to run. He learned that some distances shorten themselves if you look at them right.",
    sprite = "assets/items/saviors_watch.png",
    type = "utility",
    tags = { "charm", "holy" },
    class = "fighter",
    discipline = "crusader", -- deeper cut of the shelf: buyable only once the crusader gate is cleared
    price = 345,
    unlockQuests = 2,
    traits = { "trait_saviors_watch" },
    -- A floor for the fights nobody gets hurt in. Magic defense rather than defense: the Crusader is
    -- already the heaviest body on its own shelf, and what a fighter x priest is actually short of is
    -- the ward, not the plate.
    bonus = { magicDefense = Curve.ramp(1, 11) },
}
