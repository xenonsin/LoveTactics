-- TIME WAS: one of the Brazen Head's two drops (data/characters/character_brazen_head.lua; "Envy's Bestiary",
-- 2026-10-03, slice C, round 2's option A). The head's second utterance, made a Theurge's: an ally within 3
-- returns to the health it had at the start of your last turn.
--
-- The record is kept by the item's own trait (trait_time_was), written at the top of each of your turns; the cast
-- only reads it, so a preview of it changes nothing. It only ever puts health back: an ally healed since then is
-- not wound down to the old line, and an Unclosing wound refuses it like any heal.
--
-- A Theurge's, the shelf of the channelled miracle. An unstocked trophy on the seat's rung.
return {
    name = "Time Was",
    description = "An ally within 3 returns to the health it had at the start of your last turn.",
    flavor = "It does not undo anything. It only says, very firmly, how things were.",
    sprite = "assets/items/ability_time_was.png",
    type = "ability",
    tags = { "holy", "magical" },
    class = "theurge",
    unlockLevel = 12,
    unstocked = true,
    traits = { "trait_time_was" },
    activeAbility = {
        target = "ally",
        range = 3,
        speed = 4,
        cost = { stat = "mana", amount = 10 },
        cooldown = 15,
        effect = function(fx)
            local t, user = fx.target, fx.user
            local record = user and user.timeWas and user.timeWas.last
            local was = t and record and record[t]
            if not was then return end
            local lost = was - t.char.stats.health.current
            if lost > 0 then fx.heal(t, lost) end
        end,
    },
}
