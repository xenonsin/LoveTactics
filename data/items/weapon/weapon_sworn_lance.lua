-- A spear, so it skewers a line (docs/weapons.md). Its extra is that the two bodies it runs through are
-- sworn to each other (status_sworn): from then on, either of them that ends a turn away from the other
-- takes raw damage for it.
--
-- Quest-only: `class` with no `price`.
--
-- Acedia's rule, taken off her and turned around -- data/traits/trait_unrelieved.lua is where the oath
-- comes from, and she uses it on your party. The pike is the answer in kind: a knight who has faced the
-- General of Sloth and came back with the trick. Which is why it is a spear and could not be anything
-- else -- the LINE is what pairs them. You do not choose who is bound to whom; the geometry does, and
-- the geometry is two bodies that were already standing one behind the other.
--
-- What it actually does to a fight is take the enemy's positioning away without touching their movement.
-- Nothing here roots or halts anybody. They can spread out, flank, retreat, do all of it -- and every one
-- of those turns costs them blood, because the whole reason a rank stands in a rank is now enforced. It
-- punishes the enemy for playing well.
--
-- The bite is raw (armor turns a spear; it does nothing about being alone), and the oath lasts the
-- battle, so a single good thrust into a formation shapes the rest of the fight.
return {
    name = "The Sworn Lance",
    description = "Skewers the two tiles ahead and swears them to each other: either one that ends a turn apart bleeds for it.",
    flavor = "She bound your people to each other to prove that they would leave each other. The Bastion had the pike reforged and did not argue the point.",
    sprite = "assets/items/sworn_lance.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "melee" },
    hands = 2,
    class = "knight",
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        -- Under an iron spear's: the oath outlasts the wound by the whole battle.
        damage = { 4, 4, 5, 5, 6, 6, 7, 8, 8, 9, 9 },
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            local caught = fx.aoeUnits()
            for _, u in ipairs(caught) do
                fx.damage(u)
            end

            -- An oath needs two parties. One body in the line is simply skewered -- and that is the
            -- weapon's discipline, the same as the Splitting Maul's: it must be AIMED at a formation.
            local a, b = caught[1], caught[2]
            if not (a and b and a.alive and b.alive and a ~= b) then return end
            -- The partner is stamped onto the live instance after the fact -- Status.instantiate keeps
            -- only its own declared fields, and two copies of the blueprint must be able to be sworn to
            -- different people (the note in data/traits/trait_unrelieved.lua).
            local sa = fx.applyStatus(a, "status_sworn", { magnitude = 5 + fx.level })
            local sb = fx.applyStatus(b, "status_sworn", { magnitude = 5 + fx.level })
            if sa then sa.partner = b end
            if sb then sb.partner = a end
            fx.log("action", string.format("%s and %s are sworn to each other.",
                (a.char and a.char.name) or "One", (b.char and b.char.name) or "the other"))
        end,
    },
}
