-- Second Utterance: the standing rule behind data/status/status_second_utterance.lua. Every time one of
-- the bearer's channels LANDS, it banks a charge; the next channeled spell it casts spends that charge
-- and resolves with no wind-up at all.
--
-- A pure marker with no hooks of its own, exactly like data/traits/trait_second_wind.lua and for the same
-- reason: the rule lives at the two points in Combat that already own the channel's life --
-- Combat.resolveChannel grants the charge, Combat.useItem's channel branch spends it -- so any relic that
-- grants this trait behaves identically without either end learning about relics.
--
-- WHAT IT ACTUALLY CHANGES, since "casts faster" undersells it. A channel is a TELEGRAPH: `ab.channel`
-- ticks in which every other unit gets a turn to walk out of the painted tiles, and hard control shatters
-- the cast outright (Combat.interruptChannel). Skipping the wind-up does not just save time -- it removes
-- the counterplay. Nobody steps clear of a Meteor Storm that was never announced, and nobody stuns it out
-- of the caster's hands. That is what makes one charge worth a whole spell, and why it can only ever be
-- earned by first eating the telegraph on a channel that DID resolve.
--
-- WHY IT IS PRIDE'S. The Arcanum's whole claim is that it has finished learning (docs/story.md). This is
-- that claim as a mechanic: the second saying of a thing costs the mage nothing, because the difficulty
-- was never in the working, only in having done it once. Note the shape it shares with the shelf's other
-- new relic -- a graven circle pays the mage who cut it and nobody else, and this pays the mage who
-- already cast the spell. Both are pride's answer to a cost: not paying it twice.
return {
    name = "Second Utterance",
    description = "When a channel of yours resolves, your next channeled spell needs no wind-up.",
    -- Read by Combat.resolveChannel through Trait.has, exactly as Combat.canOverchannel reads its own.
}
