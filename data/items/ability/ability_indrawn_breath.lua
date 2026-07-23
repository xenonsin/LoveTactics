-- Indrawn Breath: the mage takes a breath in, and the board comes with it. Everything standing in a
-- wide circle is dragged to a tile beside the caster, and then the whole heap takes a blow.
--
-- The purest positional spell on the pride shelf. It deals real but unremarkable damage; what it sells
-- is GEOMETRY. A scattered enemy line is the hardest thing in this game to fight -- every AoE the party
-- owns catches one body, every knight guard covers one ally -- and there was previously no way to do
-- anything about it except wait. This makes the scatter into a heap, on your terms, on your turn, and
-- everything the party has been holding suddenly has three targets.
--
-- Which is why the damage is small and the mana is not. The turn after this one is the turn that wins;
-- this turn only sets it up, and it sets it up for somebody else's item.
--
-- IT DRAGS ALLIES TOO. fx.aoeUnits catches every body in the footprint, and a caster who breathes in a
-- melee has just pulled their own knight out of the doorway they were holding. There is no version of
-- this spell that is safe to cast into a mixed fight, and that is the point of the wind-up: the enemy
-- gets a turn to see it coming, and so does the player, who has one last chance to notice where their
-- own people are standing.
--
-- ADJACENCY: it wants an `arcane` item beside it. Nothing about hauling bodies is elemental, so it
-- cannot borrow a fire stone's tags or a frost charm's bite -- the only thing that makes the breath
-- work is raw craft sitting next to it in the grid.
return {
    name = "Indrawn Breath",
    description = "Drags every body in a wide circle to the caster's side, then strikes them all.",
    flavor = "The Arcanum teaches that the world is mostly empty space. This is the demonstration.",
    sprite = "assets/items/ability_indrawn_breath.png",
    type = "ability",
    tags = { "arcane", "magical" },
    class = "mage",
    price = 420,
    repRank = 4,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 5,
        channel = 3, -- the breath is drawn in before it is taken: a turn's warning, for both sides
        cost = { stat = "mana", amount = 20 },
        damage = { 6, 6, 7, 8, 8, 9, 10, 10, 11, 12, 12 },
        aoe = { radius = 2, shape = "square" },
        -- Only worth the mana against a spread the party can then punish. `count_at_least 2` is the
        -- floor rather than the ideal -- the scorer already sums the blast over everyone it catches and
        -- prices friendly fire above enemy damage, so it finds the good breath without being told how.
        requiresAdjacent = { tag = "arcane" },
        ai = { priority = "high", act = "attack",
               when = { subject = "any_foe", test = "count_at_least", value = 2 } },
        effect = function(fx)
            -- Pull first, strike second, and in that order for a reason: fx.pull walks its victim in
            -- one tile at a time, springing every trap and hazard on the way, so the drag itself is
            -- half the damage against a board the party has prepared. Striking first would be striking
            -- them where they were rather than where the spell put them.
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user then fx.pull(u) end
            end
            -- Re-read the footprint rather than reusing the list above: the pull has MOVED everyone,
            -- and a few of them are now standing outside the circle they were caught in (a heap beside
            -- the caster is smaller than the circle it came from). Striking the fresh set is what keeps
            -- the spell honest -- it hits who it actually gathered.
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 1)) do
                if u ~= fx.user then fx.damage(u) end
            end
        end,
    },
}
