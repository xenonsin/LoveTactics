-- SCARRING BLOWS: the Troll Scarlord's rule (data/items/utility/utility_scarring_blows.lua) and the Scarring
-- Club's (data/items/weapon/weapon_scarring_club.lua). Approved 2026-10-04 ("Sloth's Bestiary", slice B).
--
-- The club's blow lays the Unclosing Wound -- the one word this game has for "cannot be healed", and healing is
-- the funnel a troll's regrowth runs through too, so one status closes both. This is the other half: the wound
-- lasts until the striker's NEXT turn, and comes off every body it opened it on as that turn opens. So the
-- answer is the review's: heal before it swings, not after.
return {
    name = "Scarring Blows",
    description = "A foe your club strikes cannot be healed or regrow until your next turn.",
    onTurnStart = function(ctx)
        if ctx.unit and ctx.combat then require("models.sloth_trolls").closeScars(ctx.combat, ctx.unit) end
    end,
}
