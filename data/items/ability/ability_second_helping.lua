-- SECOND HELPING: devour a fallen body beside you and take two meals from it (status_full: +2 Damage, +2 Defense,
-- -1 Movement apiece) -- and while that Full lasts, nothing can push or pull you. A fat body plants itself.
-- Approved on review (2026-09-23) as a Knight's, with the note "shouldn't be a knight ability"; it went to
-- the Necromancer, whose shelf is corpses already, on the follow-up question.
--
-- The plant rides the INSTANCE (`unmovable`, read by Status.blocksForcedMove), so it is this grant's alone:
-- a Distended Girth's Full or a Bottomless Gut's does not pin anybody.
return {
    name = "Second Helping",
    description = "Devour a fallen body beside you: gain 2 meals (+2 damage, +2 defense, -1 movement). Full, you cannot be moved.",
    flavor = "The dead were going to waste. Now they are going to you.",
    sprite = "assets/items/ability_second_helping.png",
    type = "ability",
    tags = { "dark", "magical" },
    class = "necromancer",
    unlockLevel = 4,
    unstocked = true,
    activeAbility = {
        target = "tile",
        support = true, -- a meal is for the eater: preview green
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "mana", amount = 8 },
        effect = function(fx)
            -- A body that has only just gone down is still in its revive window, not yet a corpse; it
            -- is eaten all the same (Combat.devour takes either).
            local body = fx.corpseAt(fx.tx, fx.ty) or fx.downedAt(fx.tx, fx.ty)
            if not body or not fx.devour(body) then return end
            local st = fx.applyStatus(fx.user, "status_full",
                { magnitude = 2, statBonus = { damage = 2, defense = 2, movement = -1 } })
            if type(st) == "table" then st.unmovable = true end
        end,
    },
}
