-- Silencing Blade: the Spellbreaker's own weapon (knight x mage). It gags what it cuts, and it cuts
-- deeper the more a caster still had to spend.
--
-- The sword family's contract is the parry (docs/weapons.md), and this keeps it -- a spellbreaker is a
-- knight first, and a blade that could not answer a blow would be the wrong object for a discipline
-- built on standing next to a mage. What it adds is the gag: Silence stops mana being spent, and it
-- carries `interruptsChannel = "mana"`, so a wind-up caught by this blow shatters and the mana is gone
-- unrefunded. That is the one interruption this shelf kept, and it kept it because it arrives on the end
-- of a sword rather than as a veto -- you had to walk over and hit them.
--
-- The damage reading the target's REMAINING mana is what makes it a spellbreaker's blade rather than a
-- sword that happens to Silence. It is worth most against a full caster and least against a spent one,
-- which is precisely the opposite of Empty Vessel beside it -- so the two are a sequence rather than a
-- stack: open with the blade while the pool is deep, finish with the vessel once it is dry.
return {
    name = "Silencing Blade",
    description = "Inflicts Silence. Increase damage by 1 per 10 mana the target holds.",
    flavor = "Whatever he was about to say, he was going to need the whole breath for it.",
    sprite = "assets/items/weapon_silencing_blade.png",
    type = "weapon",
    tags = { "sword", "slash", "physical", "melee" },
    class = "knight",
    discipline = "spellbreaker",
    price = 440,
    unlockQuests = 10,
    traits = { "trait_parry" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = { 5, 6, 6, 7, 8, 8, 9, 10, 10, 11, 12 },
        effect = function(fx)
            -- A tenth of what is left in the pool, so the blade is at its best against a caster who has
            -- been saving up -- and unremarkable against one already spent, which is Empty Vessel's job.
            local pool = fx.target and fx.target.char and fx.target.char.stats
                and fx.target.char.stats.mana
            local held = pool and pool.current or 0
            fx.damage(fx.target, { amount = fx.amount + math.floor(held / 10), inflicts = "status_silenced" })
        end,
    },
}
