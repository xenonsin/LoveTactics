-- Clear Out: one turn on the spot that opens everything standing next to you. The fighter's answer to
-- being surrounded, and the plainest expression of wrath's own geometry (docs/classes.md): it does
-- not reach, it does not aim, it simply costs everyone who came within arm's length.
--
-- Deliberately the SELF-centred sibling of Cleave (data/items/ability/ability_cleave.lua). Cleave
-- picks a facing and sweeps the three tiles in front; this one gives up the choice of facing and
-- takes the whole ring instead -- which is the trade the two abilities exist to offer. A cleave asks
-- "which way are they?"; a clear out answers "all of them", and means all eight cells of the box it
-- stands in the middle of.
--
-- This is also the ability Rowan hands the player mid-fight in the prologue's village defense, and
-- the lesson it teaches is the ring: stand BETWEEN two foes and both fall at once
-- (data/tutorials/village.lua). Its level-0 damage is tuned so that one clear out kills an imp outright.
--
-- IT SPINS SOMETHING, AND THE SOMETHING DECIDES HOW WIDE. `requiresAdjacent` puts a melee weapon in
-- the cell beside it -- a spin with nothing in your hands is a gesture -- and `radiusFromAdjacent`
-- then lets that weapon set the ring: the longest authored reach among the melee weapons touching it
-- becomes the radius of the box (Combat.borrowedRadius, folded into Combat.aoeRadius so the cast, the
-- red preview and the card's footprint are one figure). A hooked bell that fights at two tiles clears
-- two tiles; an axe clears the arm's length it has. The authored 1 below is the FLOOR every melee
-- weapon in the game clears, so the shelf and the stash -- which have no grid to read -- quote a ring
-- the ability always manages (tests/tactics_ability_spec.lua sweeps the predicate's set to hold both
-- ends of that true, the floor and the widest reach the borrow can be handed).
local Curve = require("models.curve")

return {
    name = "Clear Out",
    description = "Spins on the spot, cutting every foe in reach. Reaches as far as the melee weapon beside it, which it needs.",
    flavor = "A cleave asks which way they are. This one has stopped asking.",
    sprite = "assets/items/ability_clear_out.png",
    type = "ability",
    tags = { "slash", "physical" },
    class = "fighter",
    price = 565,
    -- Rank 1, not 3: the player is handed this mid-prologue (see above), so a shelf that withheld it
    -- until the third quest would be gating an ability they already own and have already been taught.
    unlockLevel = 11,
    activeAbility = {
        -- Aimed at the caster's own tile: the ring is centred on the body that spins, so there is
        -- nothing to pick but yourself (states/battle.lua's computeRange gives a self-target exactly
        -- one legal cell, its own).
        target = "self",
        -- Stated outright rather than left to default to 1. A self-cast has no reach to pick --
        -- computeRange hands it exactly one legal cell whatever this says -- and every other
        -- self-target ability in data/items declares 0. The tooltip reads it: at 0 it drops the Range
        -- row and its reach diagram entirely, so the card stops printing a number (and drawing a
        -- picture) that says you may aim this a tile away.
        range = 0,
        -- ...but it is not a KINDNESS, which is the one thing a self-target otherwise implies:
        -- Combat.isSupportAbility reads ally/self as friendly and would paint the ring green. Saying
        -- so outright overrides that, so the footprint previews red like every other blow.
        support = false,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(12, 22),
        -- A melee weapon has to be touching it in the grid. Not a flavour gate: the ring's whole
        -- geometry is borrowed off that weapon below, so an ability that let itself be cast beside a
        -- bow would be spinning a thing nobody is holding.
        requiresAdjacent = { type = "weapon", tag = "melee" },
        -- THE EIGHT TILES AROUND YOU, CORNERS INCLUDED -- the whole box, not the plus. A spin on the
        -- spot has no facing and no gaps: a diagonal is exactly where a foe stands once it has worked
        -- round your shoulder, and those four cells are what being surrounded is largely made OF. A
        -- diamond answered a corner with "not that one", which is the single reading this ability may
        -- never support. It is also why the ring costs 10 stamina and a whole turn.
        aoe = { radius = 1, shape = "square" },
        -- ...AND THE BOX IS AS WIDE AS THE ARM SWINGING IT. The radius above is the floor; the reach of
        -- the longest melee weapon beside this one raises it (see the header). Same predicate as the
        -- requirement on purpose -- the weapon that makes the cast legal is the weapon that sizes it,
        -- so there is never a grid where the gate reads one neighbour and the ring another.
        radiusFromAdjacent = { type = "weapon", tag = "melee" },
        effect = function(fx)
            -- Foes only. The ring is centred on the caster and every ally at their shoulder stands
            -- inside it -- a clear out that cut your own line would be unusable in the one situation it
            -- exists for, which is being surrounded with your back to a friend.
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then fx.damage(u) end
            end
        end,
    },
}
