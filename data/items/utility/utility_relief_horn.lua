-- Quest reward, slot 1 of the Bastion's line (data/quests/relief_column.lua). The horn a relief
-- column sounds when it arrives -- the sound the garrison at Greywatch never heard.
--
-- `class = "knight"` with NO `price`: unbuyable, and still tallying toward knight growth when it is
-- used (Combat.useItem -> Character.recordUse; see docs/classes.md, "class without price"). That is
-- the whole mechanism for a quest-only item, and it beats inventing a flag.
--
-- The verb is the knight's own displacement, turned inward. The shelf owns knockback and the wait-swap
-- (docs/classes.md); this shoves an ALLY instead of a foe, and hands them the brace. Relieving a post
-- means standing in it yourself, so the horn swaps the two bodies and leaves the one you pulled out
-- braced for what is coming -- which is the Bastion's doctrine reduced to a single action.
return {
    name = "Relief Horn",
    description = "Swap places with an adjacent ally and brace them where they land.",
    flavor = "A relief column sounds one on arrival. It is the only part of the doctrine that was " ..
        "ever any use to the people waiting.",
    sprite = "assets/items/relief_horn.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    activeAbility = {
        target = "ally",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            local target = fx.target
            if not target then return end
            -- fx.swap trades tiles with the ACTING unit, so it takes the ally alone.
            fx.swap(target)
            fx.applyStatus(target, "status_defending")
        end,
    },
}
