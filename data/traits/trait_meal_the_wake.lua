-- The Wake: the kitchen skill on the Cold Board, the Cafe's funeral spread. When one of the company goes down, the
-- rest of them set their jaw -- defense and damage, banked for the rest of that battle.
--
-- Monster Hunter's Felyne Insurance, read from the other side. There the skill softens what a cart
-- costs YOU; a party game has no cart, it has the four people still standing, so the same idea lands
-- better as what the loss does to them. Same bargain either way: you are paying at the counter for the
-- fight going badly, which is the only kind of insurance worth eating.
--
-- BANKED, NOT LIVE, and that is the whole design of it. Every other reading would be worse:
--   * a `live` version keyed on "allies down" would UNDO itself the moment somebody was revived, which
--     turns a mend into a debuff and makes the correct play leaving your dead where they lie;
--   * one keyed on wounded allies is trait_saviors_watch, which already exists on the priest's shelf.
-- A wake is a thing that HAPPENED. It does not un-happen because the body got up.
--
-- Fires on `onAnyDeath` -- the one hook that is about somebody else -- and narrows it to the bearer's
-- own side. The hook already refuses summons and decoys on its own account (Trait.onAnyDeath's header),
-- which is what stops the skill's real instruction being "bring something disposable and kill it"; the
-- `summoned` check below is kept anyway, since a rule that would be an exploit if it ever slipped
-- should say what it requires rather than inherit it.
--
-- Stacks per body lost, uncapped, because at MAX_FIELD 4 the ceiling is three and a company down to its
-- last member has earned every point of it.
return {
    name = "The Wake",
    description = "Each time an ally falls, the rest of the company steadies: defense and damage, kept.",
    defense = 3,
    damage = 2,
    onAnyDeath = function(ctx)
        local fallen = ctx.fallen
        if not fallen or fallen == ctx.unit then return end
        if fallen.side ~= ctx.unit.side or fallen.summoned then return end
        ctx.addBonus("defense", ctx.def.defense or 3)
        ctx.addBonus("damage", ctx.def.damage or 2)
        ctx.log("action", string.format("%s sets their jaw.", (ctx.unit.char and ctx.unit.char.name) or "Unit"),
            ctx.unit)
    end,
}
