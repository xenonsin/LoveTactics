-- The Backward Glance: one body is put back on the tile it stood on at the start of its previous turn.
-- Whatever it spent that turn doing to get where it is now, it did for nothing.
--
-- UNDO AS A SPELL, and there is nothing else like it here. Every other displacement in this catalog
-- moves a target a fixed distance in a direction the caster chooses: a shove goes away, a pull comes
-- closer, a swap trades. This one goes BACKWARDS, by however far the target came, in whatever direction
-- it came from -- so its strength is entirely decided by what the enemy did on their own turn. A foe
-- that held its ground is barely moved. A foe that sprinted five tiles to reach your healer is sent
-- five tiles back, and has to spend its next turn doing the same thing again.
--
-- Which makes it the purest expression of the knight's shelf in the game: it deals nothing, it kills
-- nobody, and it takes an entire turn away from the enemy piece that was most committed to doing
-- something. Sloth is not damage. It is the tax on having moved.
--
-- It reads two remembered tiles kept on every unit by Combat.startTurn (`priorX/priorY`) and sends the
-- target to the OLDER of them -- deliberately not to where its current turn opened, which for a unit
-- that has not moved yet is simply where it is standing, and would make the spell do nothing at all.
--
-- IT CAN FAIL, and the failures are all honest ones: a unit in its first turn has no "before" to be
-- returned to, and ground that has since been walled, occupied or otherwise closed will not take a
-- body. Combat.recall reports false and the cast is spent. The spell promises a rewind, not a
-- guarantee that the past is still there.
--
-- ADJACENCY: a `spear` beside it. The glance is thrown out along a reach, and the knight's own polearm
-- family is what carries it -- which keeps this competing with the Mailpiercer and the Forsworn Pike
-- for the same slots rather than being free to bolt onto any loadout.
return {
    name = "The Backward Glance",
    description = "Sends one body back to the tile it stood on at the start of its last turn.",
    flavor = "The Bastion does not undo things. It simply declines to accept that they were done.",
    sprite = "assets/items/ability_backward_glance.png",
    type = "ability",
    tags = { "arcane" },
    class = "knight",
    price = 380,
    repRank = 4,
    activeAbility = {
        target = "enemy",
        range = 6, -- long: the whole value is reaching the piece that just committed to a move
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 12 },
        support = true, -- it lands no damage of its own
        requiresAdjacent = { tag = "spear" },
        effect = function(fx)
            -- Everything is in Combat.recall, including every reason it might refuse. The effect does
            -- not check the ground itself, because a data file that duplicated those checks would be a
            -- second opinion about walkability -- and the two would drift.
            if not fx.recall(fx.target) then
                fx.log("action", "There is nowhere to send it back to.", fx.user)
            end
        end,
    },
}
