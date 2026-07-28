-- Crack the Guard: a jarring blow that knocks a foe's stance loose so it never resets -- the struck
-- target is left Vulnerable: Impact (data/status/status_vulnerable_impact.lua), taking +8 from every
-- impact hit that follows. Every mace and hammer that lands after finds a body that cannot brace.
--
-- On the knight shelf because impact is the mace's tag and the mace is knight's cluster (docs/classes.md),
-- and because deciding where and how a body may stand is exactly the wall's argument. Until this, impact
-- was amplified only through a Frozen target -- so the blunt line could never set up its own follow-up
-- without an ice mage. This unbundles it: a mace-and-hammer wall rewards stacking impact on its own now.
-- See docs/vulnerability.md for the family.
return {
    name = "Crack the Guard",
    description = "Deals impact damage and inflicts Vulnerable: Impact.",
    flavor = "A shield is only as good as the shoulder behind it. Crack the shoulder.",
    sprite = "assets/items/ability_crack_the_guard.png",
    type = "ability",
    tags = { "impact", "physical", "melee" },
    class = "knight",
    price = 240,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        damage = { 6, 7, 7, 8, 9, 9, 10, 11, 11, 12, 13 },
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_vulnerable_impact" })
        end,
    },
}
