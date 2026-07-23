-- Toll the Knell: the Arcanum names an hour for somebody, and the hour keeps. Lays Knell
-- (data/status/status_knell.lua) on one foe -- a plain count that, when it reaches zero, kills whatever
-- is wearing it regardless of health, armor or rank.
--
-- It does NO damage, and that is the item. Every other spell on the rack asks how hard it can hit
-- something; this one declines the question entirely and asks the party a different one -- can you keep
-- it alive for four turns, and what will it cost you to try. Against a wounded body it is worse than a
-- Fire Bolt. Against the thing with three hundred health that your damage cannot get through, it is the
-- only spell on the shelf that works, and it works exactly as well.
--
-- THE FOUR THINGS THAT MAKE IT FAIR, since a guaranteed kill has to answer for itself:
--
--   * The tell. `channel = 3` -- three ticks of wind-up in which every foe gets a turn, and any hard
--     control shatters the cast outright (Combat.interruptChannel). It is the most interruptible thing
--     the mage owns, and the mana is gone whether it lands or not.
--   * The cure. Knell is `debuff = true`, so a Cure, a Panacea or any dispel lifts it whole. The enemy
--     AI's healer will use one. What the spell really buys is a turn of somebody else's time.
--   * The clock is public. The badge counts down in plain sight with the hourglass on it, so the target's
--     side can see the hour coming and decide what it is worth (see the status file on why the count is
--     the duration rather than a hidden counter).
--   * The price. The heaviest mana cost on the shelf, and it is spent up front at cast-start.
--
-- WHY IT IS PRIDE'S rather than the Undercroft's, which is where a death sentence would usually sit. A
-- rogue's execute is a knife finding a gap -- it asks the victim to already be weak. This asks nothing of
-- the victim at all. It is the Arcanum stating a fact about somebody else's future and expecting the
-- world to comply, and being right (docs/story.md: "I finished learning an age ago"). The spell does not
-- kill anyone. It announces, and the announcement is what kills them.
--
-- The forge buys a SHORTER fuse, never a cheaper cast: 20 ticks at base down to 15 fully honed. An
-- upgrade should make the sentence harder to outrun, not make sentences cheap enough to hand out.
return {
    name = "Toll the Knell",
    description = "Names an hour for one foe. When the count runs out they die, whatever their health. Cleansable.",
    flavor = "He did not do anything to her. He simply said when, and was not contradicted.",
    sprite = "assets/items/ability_knell.png",
    type = "ability",
    tags = { "magical", "dark" },
    class = "mage",
    price = 640,
    repRank = 4,
    activeAbility = {
        target = "enemy",
        range = 5,
        requiresSight = true,
        channel = 3, -- the tell, and the counterplay before the counterplay
        speed = 6,
        cost = { stat = "mana", amount = 28 }, -- the shelf's heaviest, spent at cast-start either way
        effect = function(fx)
            -- 20 ticks at level 0 down to 15 at level 10: honing tightens the window the enemy has to
            -- find a cure in. It carries no `damage`, so the tooltip leads with the duration instead --
            -- which is the number that says what this item IS.
            fx.applyStatus(fx.target, "status_knell", { duration = 20 - math.floor(fx.level / 2) })
        end,
    },
}
