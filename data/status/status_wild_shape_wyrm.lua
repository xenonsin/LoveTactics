-- Wild Shape (Wyrm): the timer that owns Mira's fourth body. The shape itself is worn by the relic's
-- effect (data/items/utility/utility_borrowed_pelt.lua) rather than by an onApply hook here, exactly as
-- the three shelf shapes do it and for the same reason -- a self-transform is sustained like a summon,
-- and only the cast knows what reservation its own ability declared.
--
-- Not a debuff: she did this to herself, and Cure washes away what was done TO you. So a shifted druid
-- cannot Panacea out of it early; the commitment is the price of the body.
--
-- LONGER THAN THE OTHER THREE (45 against their 30) because it is the one that has to be earned. The
-- shelf shapes are bought and cast at will; this one opens only after she has already changed twice
-- this fight, so by the time it lands there is less fight left to spend it in.
--
-- onExpire is the single reversion point and fires on EVERY removal path, so there is no way to end
-- this status and leave a druid as a wyrm. See data/status/status_wild_shape_raven.lua, which is this
-- file with one word changed.
return {
    name = "Wyrm Shape",
    abbr = "Wyrm",
    description = "Wearing a wyrm's body: it moves through the ground rather than across it.",
    color = { 0.404, 0.360, 0.300 }, -- badge tint (old earth)
    duration = 45,
    -- A lie told about a body, so Dispel Illusions strips it -- the shape's real counterplay, and the
    -- one Cure cannot touch.
    illusion = true,
    onExpire = function(ctx)
        ctx.revert() -- releases the shape's reserved mana with it
    end,
}
