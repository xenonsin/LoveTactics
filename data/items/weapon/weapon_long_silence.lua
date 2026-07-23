-- A longbow, so it is drawn before it looses and reaches five tiles (docs/weapons.md). Its extra is what
-- the shaft takes away: the target is Silenced (status_silenced) and cannot cast anything paid for in
-- mana until it lifts.
--
-- The hunter shelf's top rung alongside the Hailfall, and the party's only way to reach an enemy caster
-- that has correctly stood at the back. Every other silence in this game is a spell -- which is to say it
-- is cast by your own mage, at your own mage's range, into the teeth of theirs. This is delivered by
-- somebody standing five tiles away who was never in the exchange.
--
-- The draw is what makes it fair, and it is a real window: the enemy caster gets a full turn between the
-- archer committing and the arrow arriving, and that turn is the one they will spend casting the thing
-- you were trying to stop. So it is not an interrupt. It is a way of deciding that their SECOND spell
-- does not happen, which against a boss with a long working is the whole fight.
--
-- Note the archer's own cost is stamina, so this is not itself sorcery and cannot be silenced in return
-- -- the asymmetry is the point of putting the effect on a bow.
return {
    name = "The Long Silence",
    description = "A drawn shaft that silences: the target cannot spend mana on anything until it lifts.",
    flavor = "Five tiles is further than a conversation carries. The Lodge considers this the whole design brief.",
    sprite = "assets/items/long_silence.png",
    type = "weapon",
    tags = { "longbow", "pierce", "physical", "ranged" },
    hands = 2,
    class = "hunter",
    price = 720,
    repRank = 4,
    activeAbility = {
        target = "enemy",
        range = 5,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        channel = 2,
        cost = { stat = "stamina", amount = 10 },
        -- Under the iron longbow's: taking a caster's whole kit away is worth more than the arrow.
        damage = { 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            fx.damage(t)
            if t.alive then fx.applyStatus(t, "status_silenced") end
        end,
    },
}
