-- DEVOTION: the kobold's faith, carried on Underfoot (data/items/utility/utility_underfoot.lua).
-- Round 2 (2026-09-25), on Keno's round-1 note on the line: "Near Dragon gain bonus".
--
--   THE DRAGON'S EYE   within 3 tiles of a dragon on its side -- an egg, a Wyrmling, the Godling -- a
--                      kobold fights harder: +2 Damage, +1 Defense, for as long as it stays close. A
--                      LIVE read (Trait.liveBonus), so it follows a dragon that walks and ends the
--                      instant the kobold steps off or the dragon falls. It does not stack: two eggs are
--                      one god.
--   FERVOR / FORSAKEN    are the DRAGON's half, fired from its own hurt and death (trait_dragonkin): a
--                      kobold that sees its dragon struck is driven to Fervor, one that sees it destroyed
--                      is Forsaken. This file only carries the flag that makes a body devout.
--
-- So the kobolds are strongest exactly where the company has to go -- beside the egg, beside the
-- Godling -- and the choice is to pull them off it, or to kill the dragon and break them all at once.
return {
    name = "Devotion",
    description = "Within 3 of a dragon on your side: increase damage and defense. See it struck, Fervor; see it destroyed, Forsaken.",
    devout = true,
    live = function(ctx)
        if not ctx.combat then return nil end
        local Devotion = require("models.devotion")
        local dragon, gap = Devotion.nearestDragon(ctx.combat, ctx.unit)
        if dragon and gap <= Devotion.EYE_RADIUS then return { damage = 2, defense = 1 } end
        return nil
    end,
}
