-- THE LONG GALLERY: the Lust circle's third ordinary fight, and the cheapest place to learn the whole
-- of what the succubus line does.
--
-- ONE SUCCUBUS AND SOME PEOPLE. That is the shape of every stop on this line and it is deliberately
-- legible at the smallest rung: a lesser succubus, and one of the Cathedral's own knights standing
-- beside her wearing a Charm badge he did not put on. He is not a demon. He is in plate, he swings a
-- sword off a shelf the player shops at, and he is hers because the church blooded him and the blood
-- was never the church's (data/traits/trait_the_blooded.lua, and the Unbidden's own header).
--
-- SO THE LESSON IS ONE MOVE LONG. Kill the succubus and the knight comes back to himself and walks off
-- the board -- he has no side of his own left to be handed to, so the binding ending is him leaving
-- (status_charm's onExpire). A company that works that out here will work out the Lady Chapel, where
-- the same rule is standing between them and the body they need to reach.
--
-- WHY A GALLERY. A long gallery is the one room in a keep that is mostly LENGTH, and length is what the
-- kiss is worth: every trade moves a body down the room rather than across it, so a company that
-- entered in a rank leaves the exchange in a queue, strung out past the doorways its line was holding.
-- The Thinwall Keep does the rest, exactly as it does for the gust (data/biomes/castle.lua).
--
-- AND IT IS THE OPPOSITE FIGHT TO THE CISTERN AND THE OPEN ROOF, WHICH MAKES THREE. Up on the roof the
-- answer is to pick your ground and hold it; down in the cistern picking ground is the trap, because
-- the coils charge you for the distance you keep. In here the ground is not yours to pick at all -- the
-- bodies do not push you or hold you, they TRADE with you, and there is no stance that answers a room
-- rearranging itself around you.
--
-- HUMAN BODIES ARE BACK ON THIS FLOOR, AND THE DISTINCTION IS WORTH STATING. The 2026-09-22 sweep took
-- every encounter fielding a human `race` off the rift (97 to 67) because a human COMPANY met by a
-- company is a mirror match this combat model cannot close -- both sides mitigate, both sides heal,
-- nobody shuts the door. This is not a company. It is one or two of them, inside a demon fight,
-- charmed, with no healer of their own and a charmer who can be cut to switch them off. What was
-- removed was that fight; what is here is the circle's own rule wearing a face.
--
-- Locked to the castle stratum by ctx.biome, the same gate every circle uses. NO DEPTH GATE: ITS CIRCLE
-- IS ITS PLACEMENT. A circle owns a fixed stratum, so a depth on top of that is a second opinion about
-- where this goes, and it disagrees the moment the shuffle deals Lust at another depth
-- (Descent.sinOrder).
local Band = require("models.band")

return {
    name = "The Long Gallery",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "castle" end,
    composition = function(ctx)
        -- ONE charmer, however deep the floor. What thickens is the congregation, which is the right
        -- axis: a second succubus would double the number of party members that can be taken in a turn
        -- and turn an ordinary stop into a fight the player does not get to play.
        --
        -- AND THE CONGREGATION IS CAPPED AT TWO, WHICH IS A MEASURED NUMBER AND NOT A TASTE. At three
        -- this ran 28 unit-turns against the ordinary-stop budget of 22 (tests/skirmish_spec.lua) --
        -- an armoured body is slow to cut down, three of them plus a charmer clamps the skirmish to
        -- four bodies of nothing but plate, and the stop had grown back into a set-piece. That is the
        -- same arithmetic that took every human COMPANY off the rift, met at a smaller scale: people
        -- in armour lengthen a fight far more than their count suggests, so a stop that fields them
        -- fields fewer of them than one that fields animals.
        local list = { "character_lesser_succubus" }
        return Band.fill(list, ctx, "character_knight", { base = 2, per = 8, max = 2 })
    end,
}
