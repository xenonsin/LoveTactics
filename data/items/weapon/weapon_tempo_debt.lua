-- A hammer, so it is ponderous (docs/weapons.md) -- and it is the one that does not stun. Instead the
-- blow re-opens the wielder's own turn (Combat.grantExtraAction): swing, and act again with no enemy
-- beat in between.
--
-- Quest-only: `class` with no `price`.
--
-- A DELIBERATE DEVIATION, stated plainly as the contract asks. Every other hammer buys a stun with the
-- wielder's tempo. This one buys the tempo back and skips the stun, which is the same transaction run
-- backwards -- and the name is the mechanic: what an extra action costs is banked as Combat.tempoDebt and
-- paid in full when the unit finally stops (docs/weapons.md, "The extra action"). Nothing is created. The
-- hammer is spending tomorrow's turn today.
--
-- Why the family can afford one weapon like this: a hammer's speed 7 is the worst tempo in the game, and
-- the reason nobody wants to open a fight with one. Two hammer blows back to back at the price of
-- arriving very late afterwards is a completely different opening -- and against a foe about to die, the
-- "afterwards" may never arrive at all, which is the honest best case a burst tool should have.
--
-- It grants no second walk (the turn re-opens with the move already spent), so this is two swings from
-- where you are standing, not a swing and a reposition.
return {
    name = "Tempo Debt",
    description = "No stun -- the swing re-opens your own turn instead. You act twice now and arrive late afterwards.",
    flavor = "The Colosseum's bookmakers refuse bets on anyone carrying one. Not because it wins. Because it is difficult to time.",
    sprite = "assets/items/tempo_debt.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "melee" },
    hands = 2,
    class = "fighter",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7,
        -- Dear, and it has to be: the limiter on swinging this forever is the stamina pool, since the
        -- timeline has stopped being one. Two swings is 28 stamina out of a scarce bar.
        cost = { stat = "stamina", amount = 14 },
        -- Under an iron hammer's per swing, because the weapon lands two of them.
        damage = { 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 },
        effect = function(fx)
            fx.damage(fx.target)
            -- Granted unconditionally rather than on a kill or a hit: this weapon's whole identity is
            -- that the second swing is reliable, and a conditional version would be a worse iron hammer
            -- on every turn the condition failed.
            fx.grantExtraAction(1)
        end,
    },
}
