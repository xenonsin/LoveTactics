-- The Red Thirst: a short, enormous window in which its bearer drinks back most of what they deal.
--
-- SUSTAIN THE FIGHTER BUYS BY BEING ON SOMEBODY, which is the only kind wrath has any business
-- selling. Healing in this game is somebody else's turn -- the priest spends an action keeping the
-- front rank up -- and the front rank's own contribution to staying alive has always been armor, which
-- is passive and which the enemy simply out-damages. This is the other answer: it is worth nothing at
-- all in a turn spent walking, and worth the whole fight in a turn spent in the middle of three
-- bodies.
--
-- It STACKS with everything, and that is deliberate rather than generous (Status.lifesteal sums, and
-- is folded into the same `mods.lifesteal` the Vampiric Strike charm and a weapon's own declared
-- keyword feed). A thirsting axe swung under this, beside a charm, inside a Crimson Standard's smoke,
-- is very nearly unkillable while it is landing blows -- and completely ordinary the moment it is not.
-- Four sources of thirst is a real build, and it is a fragile one: it does nothing against a foe it
-- cannot reach, and the whole of it is undone by a single Unclosing Wound.
--
-- The counterplay is worth stating because it is the reason this can be as large as it is: heal
-- blocking exists now, blindness exists, roots exist, and all three answer this completely. A bearer
-- who is crippled at range for two turns has spent the window on nothing.
--
-- Short and expensive: it is a turn spent to make the next two turns count, and a fighter who opens
-- with it before the lines have met has thrown it away.
return {
    name = "The Red Thirst",
    description = "For a short while, drinks back most of the damage its bearer deals.",
    flavor = "The Colosseum pours it, watches, and writes the number down. It has never sold one twice to the same fighter.",
    sprite = "assets/items/utility_red_thirst.png",
    type = "utility",
    tags = { "dark" },
    class = "fighter",
    price = 440,
    repRank = 4,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2, -- fast: spending a whole turn to open a window is how the window gets wasted
        cost = { stat = "stamina", amount = 12 },
        support = true,
        effect = function(fx)
            fx.applyStatus(fx.user, "status_red_thirst", { duration = 12 + fx.level })
        end,
    },
}
