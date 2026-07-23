-- A hammer, so it stuns (docs/weapons.md). Its extra is the ground it leaves: the tile the blow lands on
-- becomes quicksand (hazard_quicksand), doubling the movement and ability costs of anything standing in
-- it.
--
-- Quest-only: `class` with no `price`.
--
-- The two halves compound in a way nothing else in the game does. A stun shoves a body down the turn
-- order once; the mire makes every turn it takes AFTERWARDS cost double, from the tile it was standing on
-- when it got stunned -- which, because it is stunned, is the tile it is going to be standing on for a
-- while. The hammer makes them late, and then makes being late expensive.
--
-- Getting out is the counterplay and it is a real one: the mire is a fact about a square, so a foe that
-- simply walks off it is free. It only costs them the walk -- at double rate -- which is the whole
-- transaction the weapon is selling. It buys turns, not kills.
--
-- Unsided as ground generally is: your own line sinks in it exactly as readily, and the tile in question
-- is by definition adjacent to the fighter, which is where the rest of the melee was heading.
return {
    name = "The Mired Maul",
    description = "Stuns, and turns the ground the blow lands on to quicksand: everything there moves and acts for double.",
    flavor = "The head is packed with river clay. The armourers say it is for the weight. It is not for the weight.",
    sprite = "assets/items/mired_maul.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "earth", "melee" },
    hands = 2,
    class = "fighter",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7,
        cost = { stat = "stamina", amount = 12 },
        -- Under an iron hammer's: the ground is the rest of the price.
        damage = { 9, 10, 11, 12, 13, 14, 15, 16, 17, 19, 20 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            -- Where it is standing NOW, read before the blow: a stun does not move anybody, but a
            -- counter-shove or a reflex fired from inside fx.damage could, and the mire belongs under
            -- the body the hammer was aimed at.
            local tx, ty = t.x, t.y
            fx.damage(t, { inflicts = "status_stun" })
            fx.placeHazard(tx, ty, "hazard_quicksand", { duration = 10 + fx.level })
        end,
    },
}
