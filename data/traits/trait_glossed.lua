-- THE GLOSS: somebody else's working pays for your answer to it.
--
--   baseline   mana back whenever a spell is worked anywhere near the bearer. Mana never regenerates on
--              its own in this game, so this is a real effect on any caster with nothing else equipped
--              -- it is the difference between a mage who runs dry on turn four and one who does not.
--   synergy    the Codex Unanswered deflects a single-target spell aimed at you FOR MANA, on a cooldown
--              (trait_counter_magic). Its real limit was never the cooldown, it was the bill: against a
--              caster party you run out and stop being able to refuse anything. The gloss is funded BY
--              the thing it funds, so the more they throw the more you can afford to unravel.
--
-- The one pair in the set that gets STRONGER the worse the matchup is, which is Sublimitas's whole
-- posture and the reason the Codex reads as arrogance rather than as a ward.
return {
    name = "Glossed",
    description = "Any spell worked nearby returns mana.",
    mana = 4,
    onAnyCast = function(ctx)
        -- Only a real working. `castAbility` is nil for an ordinary weapon swing, and paying for those
        -- would make this a flat per-turn refill rather than an answer to sorcery.
        if not ctx.castAbility then return end
        ctx.restore(ctx.unit, "mana", ctx.def.mana)
    end,
}
