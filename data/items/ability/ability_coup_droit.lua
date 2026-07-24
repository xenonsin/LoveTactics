-- Coup Droit: the payoff half of the Duelist (fighter x rogue). The straight thrust down the centre,
-- thrown once the exchange has been read -- it spends every point of Tempo and multiplies the blow by
-- what it took.
--
-- Gated on the target being DUELBOUND (status_duelbound), which is the one condition that makes a
-- multiplier this steep fair: a duelbound pair cannot walk away from each other, so the victim has had
-- every one of those exchanges to kill you first, and anyone watching can see the tempo building. It is
-- not an execute you can open with. It is the end of a conversation.
--
-- MULTIPLIES rather than adds, deliberately, and it is the one pool in the game that does: Tempo caps at
-- 5 and empties the instant you look away (utility_reading_the_blade), so the ceiling is reachable only
-- by a fighter who has spent the whole duel refusing every other target on the field. A flat bonus would
-- have made spreading your attention merely worse; a multiplier makes it a different fight.
return {
    name = "Coup Droit",
    description = "A straight thrust at a Duelbound foe, multiplied by every point of Tempo you spend.",
    flavor = "Everything before this was a question. She had been listening to the answers.",
    sprite = "assets/items/ability_coup_droit.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "fighter",
    discipline = "duelist",
    price = 360,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        damage = { 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 },
        -- A pure `when` read of the shared pool, exactly as Flurry does it: a counted `unlock.event`
        -- keeps a per-ITEM baseline, which would give this and Reading the Blade two different numbers
        -- both called Tempo.
        unlock = {
            when = function(unit) return require("models.combat").chargePool(unit, "tempo") >= 1 end,
            text = "Hold Tempo by pressing one foe",
        },
        description = "Spends all Tempo; the thrust is multiplied by what it spent. Duelbound foes only.",
        -- The duel gate lives in the EFFECT rather than in `usable`, because `usable` is handed only
        -- (unit, item) -- a pure read of the bearer and its grid, with no target in scope
        -- (Combat.itemBlockReason). So the button stays live and the thrust declines on arrival,
        -- spending nothing: no Tempo is taken and the swing lands as an ordinary one.
        effect = function(fx)
            if not fx.hasStatus(fx.target, "status_duelbound") then
                fx.log("action", "The thrust needs a duel to land in; it goes wide of the measure.")
                fx.damage(fx.target)
                return
            end
            local spent = fx.spendCharge("tempo")
            fx.damage(fx.target, { amount = fx.amount * (1 + spent * 0.4) })
        end,
    },
}
