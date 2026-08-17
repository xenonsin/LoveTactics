-- ASSAYED: the richer your company is, the harder this hits.
--
-- Greed's rule read from the other side. Aurea lifts things off you outright; the Assayer simply prices
-- what you are carrying and is worth more for it -- so the circle's difficulty is set by how the run has
-- been going, and a player who has been hoarding meets a harder floor than one who spent at the Forge.
--
-- Which makes it the one mechanic in the descent whose knob is in the player's own hands three stops
-- earlier. The counterplay is not tactical at all: it is to have spent.
--
-- `live` rather than a hook, so it tracks the purse as the chitters empty it during the fight -- an
-- Assayer whose swarm has just robbed you is reading the higher number, and killing the swarm lowers it.
--
-- The party's bank is `combat.purse = { get, spend }`, INJECTED by states/battle.lua for a campaign
-- fight and absent everywhere else -- a draft duel, a headless fixture, the arena. So this reads as
-- nothing rather than faulting off the board it was not built for, which is the same contract the rest
-- of the money kit keeps (models/combat.lua's spendPurse).
return {
    name = "Assayed",
    description = "Gains damage for the coin its foes are carrying.",
    per = 200,   -- gold per point of damage
    ceiling = 14, -- ...and the cap, so a rich run does not meet an unkillable body
    live = function(ctx)
        local purse = ctx.combat and ctx.combat.purse
        local gold = purse and purse.get and purse.get()
        if not gold or gold <= 0 then return nil end
        local n = math.min(ctx.def.ceiling, math.floor(gold / ctx.def.per))
        if n <= 0 then return nil end
        return { damage = n }
    end,
}
