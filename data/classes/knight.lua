-- Knight -- a ROOT class (sloth's house).
--
-- A root is a class with no parents and no gate: every body holds it from the first morning, and it is
-- where a career starts rather than something a career earns. That is the whole of what makes it a
-- root, and it is read off this file rather than declared -- `classes` empty means nothing stands above
-- it (Class.isRoot). See docs/class-fold.md.
--
-- The description was Item.CLASSES.knight. It lives here now because a class is one kind of thing with
-- one blueprint, and a blurb kept in a second table beside the ladder is exactly how the two axes drift.
return {
    name    = "Knight",
    description = "Decides where the enemy stands. Taunts pull attacks onto you, Knockback and Halt move "
        .. "foes off their tiles, and a guard takes an ally's hit onto your own plate.",
    exemplar = "character_rowan", -- the companion the Bastion posts; roots are the companions' own tier
}
