-- A bow, so it shoots at range and has no point-blank shot (docs/weapons.md). Its extra is that the shaft
-- marks: whatever it hits is Limned (status_limned) -- lit up, and targetable however well it is hidden.
--
-- The Lodge's answer to the one thing an archer cannot shoot, which is a thing it cannot see. Invisible,
-- Stillshade, a Vanishing Act, a Smoke Screen -- all of them turn the ranged half of a party off entirely,
-- and until now the counter was to wait it out. This shoots the answer.
--
-- Which makes it the rank-2 rung and not a higher one on purpose: it does nothing whatsoever against a
-- warband with no stealth in it. It is the bow you swap to when you see what you are fighting, and the
-- shelf should have that lesson early.
--
-- Note it lights up whoever it HITS, so the bow's own problem is unchanged -- it cannot target something
-- already unseen to shine a light on it. What it does is stop somebody vanishing afterwards, which in
-- practice means firing at the assassin before it goes and keeping it visible for the rest of the party.
return {
    name = "Limning Bow",
    description = "Fires at range and leaves the target Limned: lit up, and targetable however well it hides.",
    flavor = "The Lodge's trackers do not call it a bow. They call it the lamp, which annoys the bowyers.",
    sprite = "assets/items/limning_bow.png",
    type = "weapon",
    tags = { "bow", "pierce", "physical", "ranged" },
    hands = 2, -- every bow is two-handed
    class = "hunter",
    price = 200,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 3,
        minRange = 2, -- the family's dead zone: no point-blank shot
        requiresSight = true,
        speed = 2,
        cost = { stat = "stamina", amount = 6 },
        damage = { 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9 }, -- a shade under an iron bow's: the light is the rest
        effect = function(fx)
            fx.damage(fx.target)
            if fx.target and fx.target.alive then
                fx.applyStatus(fx.target, "status_limned")
            end
        end,
    },
}
