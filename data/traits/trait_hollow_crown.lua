-- THE HOLLOW CROWN: the last fight's rule, worn on the Crown's organ (data/items/utility/utility_the_first_archon.lua;
-- "The Crown's Bestiary", slice D, approved over rounds 3-4). Four phases, each a lesson the game already taught:
-- the court that keeps it whole, the seven wants it shows a turn ahead, the Pit that takes the board's edge, and the
-- Last Hour's count and seals. models/hollow_crown.lua argues every one in full; this file is only the hooks.
--
-- IT USED TO WEAR THE DEAD. At 75/50/25% it put a fallen general back on -- which the Many Faced One already does,
-- with every general above it, as Envy's whole rule. Two bosses saying one sentence is one boss too many, so the
-- Crown never takes a general's shape now: it reaches for the generals' RULES instead (phase 2), by their own names.
--
-- `notAReaction`: a stage is read off its own bar, so a stun cannot hold a phase down (Trait.onDamaged).
local function HC() return require("models.hollow_crown") end

return {
    name = "The Hollow Crown",
    description = "Four phases: its court keeps it whole, it acts the seven wants, the Pit opens, and the Last Hour counts down.",
    notAReaction = true,
    onCombatStart = function(ctx) HC().open(ctx.combat, ctx.unit) end,
    onTurnStart = function(ctx) HC().turnStart(ctx.combat, ctx.unit) end,
    onTurnEnd = function(ctx) HC().turnEnd(ctx.combat, ctx.unit) end,
    onDamaged = function(ctx) HC().damaged(ctx.combat, ctx.unit, ctx.amount) end,
    onDeath = function(ctx) HC().onDeath(ctx.combat, ctx.unit) end,
    -- The court falling, and the wisps it throws, are heard at every death and every turn's edge.
    onAnyDeath = function(ctx)
        HC().claimWisps(ctx.combat, ctx.unit)
        HC().advance(ctx.combat, ctx.unit)
    end,
    onAnyTurnStart = function(ctx) HC().claimWisps(ctx.combat, ctx.unit) end,
    onAnyTurnEnd = function(ctx)
        HC().claimWisps(ctx.combat, ctx.unit)
        HC().advance(ctx.combat, ctx.unit)
    end,
    onWispTaken = function(ctx) HC().takeWisp(ctx.combat, ctx.unit) end,
    onAnyCast = function(ctx) HC().saw(ctx.combat, ctx.unit, ctx.caster, ctx.castItem) end,
}
