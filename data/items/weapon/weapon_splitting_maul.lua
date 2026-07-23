-- An axe, so it cleaves (docs/weapons.md). Its extra is what the arc leaves behind: everything it caught
-- is Conjoined (status_conjoined) -- each of them now takes half of every wound the others suffer.
--
-- Which inverts the family. An axe's whole argument has always been "hit several things at once"; this
-- one hits several things at once so that afterwards you no longer have to. Cleave a rank of four, then
-- put a greatsword through ONE of them and the other three bleed for it. It turns the party's
-- single-target damage -- which is most of the party's damage -- into area damage for the rest of the
-- fight, without any of them changing weapons.
--
-- The shelf's top rung alongside the Crimson Greataxe, and the two make the same pitch to different
-- halves of the roster: the Greataxe is what a fighter carries to survive being outnumbered alone, and
-- this is what a fighter carries to make being outnumbered the party's opportunity.
--
-- Note the binding does not care whose side it caught. Cleave your own line into the conjunction and you
-- have wired your knight to the enemy's champion, which is a real way to lose a fighter.
return {
    name = "Splitting Maul",
    description = "Cleaves a wide arc and binds everything it caught: each of them takes half of every wound the others suffer.",
    flavor = "One blow to make them a crowd. After that you only ever have to hit the crowd once.",
    sprite = "assets/items/splitting_maul.png",
    type = "weapon",
    tags = { "axe", "slash", "physical", "melee" },
    hands = 2, -- a maul takes both hands: the binding is worth the free slot
    class = "fighter",
    price = 820,
    repRank = 4,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 13 },
        -- Under the iron axe's per target: what this swing is for happens on everybody else's turn.
        damage = { 4, 5, 5, 6, 6, 7, 8, 8, 9, 9, 10 },
        aoe = { shape = "front", width = 3 },
        effect = function(fx)
            local caught = fx.aoeUnits()
            for _, u in ipairs(caught) do
                fx.damage(u)
            end
            -- One body in the arc is not a conjunction -- there is nothing to share a wound with -- so
            -- the binding simply is not made, and the weapon is a weak hatchet. That is the honest cost
            -- of the design: it is the worst axe in the game against a single foe.
            if #caught < 2 then return end
            -- One bare table per swing, stamped onto every status this cast lands: it is what separates
            -- this conjunction from any other on the field, and a Conjoined with no `link` does nothing
            -- at all (see data/status/status_conjoined.lua and ability_conjunction, which mints its link
            -- the same way). May come back nil -- Conjoined is resistible, and an unbound body must not
            -- be stamped.
            local link = {}
            local bound = 0
            for _, u in ipairs(caught) do
                if u.alive then
                    local st = fx.applyStatus(u, "status_conjoined", { duration = 16 + 2 * fx.level })
                    if st then st.link = link; bound = bound + 1 end
                end
            end
            if bound > 1 then
                fx.log("action", string.format("%d bodies are split into one.", bound))
            end
        end,
    },
}
