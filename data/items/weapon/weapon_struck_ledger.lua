-- A bow, so it shoots at range with a dead point-blank band (docs/weapons.md). Its extra is that it
-- PRICES what it hits: the target is left carrying status_struck_ledger -- lit up, and worth coin to the
-- company when it falls.
--
-- Quest-only: `class` with no `price`.
--
-- The Undercroft's arithmetic on the Lodge's weapon, and the reason it is a bow rather than a knife: the
-- mark has to be applied to things you are not going to be standing next to. An archer can price the
-- whole enemy line over two turns from across the board, and then the party collects on whichever of
-- them happen to die -- to anyone, by any means. It is the only weapon here whose output is measured in
-- the campaign layer rather than in the battle.
--
-- It also lights the target up, which is the half that matters in the fight itself: a priced body cannot
-- hide, so the mark doubles as the Limning Bow's job with a bill attached.
--
-- Deliberately the worst damage on the hunter's shelf. A weapon that pays you for kills must not also be
-- good at producing them, or there is no decision -- and a run of fights where you shot everything with
-- this instead of killing it faster is a run where the party is rich and the quest went badly.
return {
    name = "The Struck Ledger",
    description = "Fires at range and prices the target: lit up, and worth coin to the company when it dies.",
    flavor = "The Undercroft's assessors do not attend battles. They send the arrows and read the receipts.",
    sprite = "assets/items/struck_ledger.png",
    type = "weapon",
    tags = { "bow", "pierce", "physical", "ranged" },
    hands = 2,
    class = "hunter",
    activeAbility = {
        target = "enemy",
        range = 3,
        minRange = 2,
        requiresSight = true,
        speed = 2,
        cost = { stat = "stamina", amount = 6 },
        -- Half an iron bow's, and that is the design rather than a tax. See the header.
        damage = { 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7 },
        effect = function(fx)
            fx.damage(fx.target)
            if fx.target and fx.target.alive then
                fx.applyStatus(fx.target, "status_struck_ledger")
            end
        end,
    },
}
