-- Still Hunt: the count of turns a body has waited without moving. Held by trait_still_hunt, which
-- lays it at the bell with no stacks and reads it as a damage bonus (a quarter of Damage per stack);
-- this status only keeps the count, and the badge is where the player reads it.
--
--   * a turn ENDED without the bearer having moved adds one, up to MAX
--   * a step of its own, or being shoved or dragged, clears it (onEnterTile fires for both)
--   * landing a blow spends it (onDealDamage, which runs after the bonus was folded into that blow)
--
-- A teleport fires no enter-tile hook, so an ability that relocates the bearer on purpose clears it by
-- hand (ability_strand_walk). Not a debuff: Cure does not take a hunter's patience away.
local MAX = 3

return {
    name = "Still Hunt",
    abbr = "Still",
    description = "Each stack adds a quarter of Damage to the next blow. Any step clears the stacks.",
    color = { 0.55, 0.60, 0.50 }, -- badge tint (lichen)
    duration = 9999, -- lives the whole fight; the count is the story, not the clock
    hideDuration = true,
    magnitude = 0,
    onTurnEnd = function(ctx)
        local turn = ctx.combat and ctx.combat.turn
        if turn and turn.unit == ctx.unit and not turn.moved then
            ctx.status.magnitude = math.min((ctx.status.magnitude or 0) + 1, MAX)
        end
    end,
    onEnterTile = function(ctx) ctx.status.magnitude = 0 end,
    onDealDamage = function(ctx) ctx.status.magnitude = 0 end,
}
