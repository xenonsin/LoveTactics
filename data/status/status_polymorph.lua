-- Polymorph: the victim is a pig. It keeps its health, its tile and its turn, and it loses every verb
-- it had -- a pig has no items and no fangs (data/characters/pig.lua), so it can walk and it can end
-- its turn, and that is the entire list.
--
-- Unlike Charm (whose ability performs the side-flip and leaves the status holding only the timer),
-- this status owns BOTH halves: onApply wears the shape, onExpire takes it off. It can, because the
-- shape costs the victim nothing to wear -- there is no reservation to bind, which is the one thing a
-- status hook cannot reach (see the upkeep note in models/transform.lua; Wild Shape is the other way
-- round for exactly that reason).
--
-- Owning both halves is what makes the reversion airtight: Status.remove and Status.cleanse both fire
-- onExpire as the status leaves, so however the spell ends -- countdown, Cure, Panacea, dispel -- the
-- pig is a knight again. There is no path that strands anyone as livestock. And because onApply runs
-- only AFTER the resistance gate (see Status.apply), a shrugged-off cast never transforms anyone: the
-- one thing that must not happen -- a pig with no timer to end it -- cannot.
--
-- `resistible = "magical"` is what keeps this from being the only spell in the game worth casting. A
-- 12-tick pig is a fight-ending sentence at full value; against magicDefense it is markedly shorter,
-- and every repeat on the same victim is halved again until the fourth simply does not land. See the
-- resistance contract in models/status.lua -- that curve, and not a coin flip, is the counterplay.
return {
    name = "Polymorph",
    abbr = "Pig",
    description = "A pig: it can move, and it can do nothing else.",
    color = { 0.95, 0.65, 0.72 }, -- badge tint (pink)
    duration = 12,
    debuff = true,             -- Cure/Panacea break the spell early
    -- A lie told about a body: this one is a knight and says it's a pig. So Dispel Illusions unravels
    -- it (Status.illusionsOn) -- which gives the shape a SECOND, quite different counter from Cure.
    -- Cure is a friendly hand reaching the victim; a dispel is an area sweep that does not care whose
    -- side the pig is on, and takes the enemy mage's Wild Shape apart in the same stroke.
    illusion = true,
    resistible = "magical",    -- warded by magicDefense + statusResist, and halved on every repeat
    interruptsChannel = true,  -- a pig is not finishing the spell it was winding up
    disablesReactions = true,  -- and it is not countering, parrying, or dodging anything either
    onApply = function(ctx)
        ctx.transform("character_pig") -- refuses (harmlessly) on a refresh: the victim is already wearing it
    end,
    onExpire = function(ctx)
        ctx.revert() -- no-op if the shape never took; fires on EVERY removal path
    end,
}
