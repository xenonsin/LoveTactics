-- The Loadout screen's three warnings: Combat.unpayableCosts (the body can never pay the price),
-- Combat.adjacencyGap (nothing beside it answers what it requires) and Combat.movementPenalty (the kit
-- is working against itself).
--
-- The first two are OUT-OF-BATTLE twins of a gate that already exists in the fight, and in both cases
-- the thing under test is the DIFFERENCE. The cost gate (Combat.canAfford) reads `current`, where this
-- one reads the ceiling -- ask the battle question on this screen and it cries wolf at every tired party
-- member. The adjacency gate has no notion of an item that is not in the grid at all, where this one has
-- to tell "placed wrong" apart from "not placed yet" -- conflate them and every good item in the stash
-- lights up as an error.
--
-- The third has no gate behind it at all, and what is under test is WHEN IT KEEPS QUIET. Nearly every
-- coat on the shelf costs Move, so a warning that fired on one would fire on every armored body in the
-- game and be worth nothing by the second time it was read.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")

-- A fighter: 5 mana, 25 stamina, 72 health, and an empty-ish grid to hang test items on.
local function fighter()
    local char = Character.instantiate("character_fighter")
    for i = 1, Character.MAX_INVENTORY do char.inventory[i] = nil end
    return char
end

-- A bare item table with one priced ability. Synthetic rather than a shipped id on purpose: the point
-- is the arithmetic, and a rebalance that moved a real staff's price would break this for no reason.
local function priced(stat, amount)
    return { id = "test_priced", name = "Test Working", type = "ability",
        activeAbility = { name = "Test Working", cost = { stat = stat, amount = amount } } }
end

-- A volley that only works next to a bow, and the bow that answers it.
local function needsBow()
    return { id = "test_volley", name = "Test Volley", type = "ability",
        activeAbility = { name = "Test Volley", requiresAdjacent = { tag = "bow" } } }
end
local function bow()
    return { id = "test_bow", name = "Test Bow", type = "weapon", tags = { "bow" } }
end

-- A coat charging `move` (negative) for itself. Synthetic for the same reason `priced` is: the point is
-- the arithmetic across a grid, and a rebalance moving a real plate's price would break this for nothing.
local function coat(move)
    return { id = "test_coat", name = "Test Coat", type = "armor", bonus = { movement = move } }
end

return {
    {
        name = "a price above the pool's CEILING is unpayable, and says by how much",
        fn = function()
            local char = fighter()
            local short = Combat.unpayableCosts(char, priced("mana", 14))
            assert(#short == 1, "one pool falls short, so one entry")
            assert(short[1].stat == "mana", "and it names the pool")
            assert(short[1].amount == 14 and short[1].ceiling == 5, "the price and the ceiling both")
            assert(short[1].text:find("14") and short[1].text:find("5"),
                "the line quotes both numbers -- a warning that does not say by how much cannot be acted on")
        end,
    },
    {
        -- The whole reason this is not Combat.canAfford. A party that walked home on an empty pool must
        -- not have its entire spellbook flagged: mana comes back, ceilings do not.
        name = "an EMPTY pool is not a warning -- only a pool too small to ever hold the price",
        fn = function()
            local char = fighter()
            char.stats.mana.current = 0
            assert(#Combat.unpayableCosts(char, priced("mana", 4)) == 0,
                "4 mana against a ceiling of 5 is payable, however drained the body is right now")
        end,
    },
    {
        name = "a cast drawing on two pools reports EVERY pool that falls short",
        fn = function()
            local char = fighter()
            local item = { id = "test_dual", name = "Test Blade", type = "weapon",
                activeAbility = { cost = { { stat = "mana", amount = 20 }, { stat = "stamina", amount = 99 } } } }
            assert(#Combat.unpayableCosts(char, item) == 2,
                "the loadout is where both get fixed, so it is handed both")
        end,
    },
    {
        -- Attunement raises the ceiling from the grid, so the answer has to be read off the gear as
        -- well as the body -- and equipping the charm has to CLEAR the warning, or the screen is telling
        -- the player to do something and then not noticing that they did it.
        name = "gear that raises the ceiling pays the price the naked body could not",
        fn = function()
            local char = fighter()
            local spell = priced("mana", 14)
            assert(#Combat.unpayableCosts(char, spell) == 1, "unpayable before the charm")
            assert(Character.addItem(char, Item.instantiate("utility_attunement")), "the charm goes on")
            assert(Character.statTotal(char, "mana") >= 14, "Attunement is worth enough to cover it")
            assert(#Combat.unpayableCosts(char, spell) == 0, "and the warning clears")
        end,
    },
    {
        -- Both of the battle gate's escape hatches have to be honoured here, or the screen warns about
        -- casts that work perfectly well. Overchannel bills the shortfall to health.
        name = "Overchannel waives a mana shortfall it has the blood to cover",
        fn = function()
            local char = fighter()
            local spell = priced("mana", 14)
            assert(#Combat.unpayableCosts(char, spell) == 1, "unpayable for a body that only has mana")
            assert(Character.addItem(char, Item.instantiate("armor_overchannel_weave")), "the weave goes on")
            assert(#Combat.unpayableCosts(char, spell) == 0,
                "a 9-point shortfall against 72 health is paid in blood, not refused")

            -- ...but only as far as the blood goes, and never lethally: the shortfall must be CLEARED.
            assert(#Combat.unpayableCosts(char, priced("mana", 500)) == 1,
                "a working nobody could bleed for is still a dead slot")
        end,
    },
    {
        -- A trait is the quieter half of the same bug: it never offers itself to be clicked, so an
        -- unpayable one does nothing at all and says nothing about it.
        name = "a trait's own price is weighed too, not just the active ability's",
        fn = function()
            local char = fighter()
            -- Counter Magic: 14 mana every firing, against the fighter's ceiling of 5.
            local short = Combat.unpayableCosts(char, Item.instantiate("utility_codex_unanswered"))
            assert(#short == 1 and short[1].stat == "mana", "the charm's trait is priced in mana it hasn't got")
        end,
    },
    {
        -- Trait.ownCost's carve-out. A counter that SWINGS is billed the weapon it throws back, so a def
        -- declaring a `cost` beside such a rule (trait_whirl_answer's 4 stamina) is never charged it --
        -- and quoting it would invent a warning about a price that does not exist.
        name = "a swing-priced answer is not billed the cost its def happens to declare",
        fn = function()
            local char = fighter()
            char.stats.stamina.max, char.stats.stamina.current = 0, 0
            local plate = Item.instantiate("armor_whirlplate")
            assert(#Combat.unpayableCosts(char, plate) == 0,
                "whirlplate's answer costs what the weapon costs, so its def's 4 stamina is not a price")

            local Trait = require("models.trait")
            assert(Trait.ownCost(Trait.instantiate("trait_whirl_answer", plate)) == nil,
                "and the rule that decides it lives on the trait, beside the answer pricing")
            assert(Trait.ownCost(Trait.instantiate("trait_counter_magic", plate)) ~= nil,
                "while a reflex that is not a swing does charge what it says")
        end,
    },
    {
        name = "a free item on any body warns about nothing",
        fn = function()
            local char = fighter()
            assert(#Combat.unpayableCosts(char, { id = "x", name = "Rock", type = "utility" }) == 0)
            assert(#Combat.unpayableCosts(char, nil) == 0, "and nil is answerable, since a grid has gaps")
            assert(#Combat.unpayableCosts(nil, priced("mana", 14)) == 0, "as is an absent body")
        end,
    },

    -- Combat.adjacencyGap ------------------------------------------------------------------------
    {
        name = "an item in the grid with nothing beside it to answer its requirement is a gap",
        fn = function()
            local char = fighter()
            char.inventory[1] = needsBow()
            char.inventory[9] = bow() -- the far corner: in the grid, but not adjacent
            local gap = Combat.adjacencyGap(char, char.inventory[1])
            assert(gap, "a bow across the grid does not answer a requirement about NEIGHBOURS")
            assert(gap.placed, "and it reports the placement failure, which is the one the player can fix")
            assert(gap.text:find("bow"), "the line names what it wants, or there is nothing to go and do")
        end,
    },
    {
        name = "the same item beside the bow is no gap at all",
        fn = function()
            local char = fighter()
            char.inventory[1] = needsBow()
            char.inventory[2] = bow()
            assert(Combat.adjacencyGap(char, char.inventory[1]) == nil,
                "cell 2 is adjacent to cell 1, so the requirement is answered")
        end,
    },
    {
        -- The distinction the battle gate has no need for. A stash item is in nobody's grid, so the
        -- in-fight reading (Combat.adjacencyMet) calls it unmet -- which on this screen would paint an
        -- error over every perfectly good volley in the stash.
        name = "a stash item some cell would satisfy is placeable, not an error",
        fn = function()
            local char = fighter()
            char.inventory[5] = bow()
            assert(Combat.adjacencyGap(char, needsBow()) == nil,
                "the bow is in the grid, so there is somewhere for this to go and the grid paints where")
        end,
    },
    {
        name = "a stash item NO cell would satisfy says so, and says whose grid it is",
        fn = function()
            local char = fighter()
            local gap = Combat.adjacencyGap(char, needsBow())
            assert(gap, "an empty grid answers a bow requirement nowhere")
            assert(not gap.placed, "and this is not a placement mistake -- it was never placed")
            assert(gap.text:find("Fighter"), "so the line names the body that is missing the bow")
        end,
    },
    {
        name = "an item that requires nothing is never a gap, wherever it sits",
        fn = function()
            local char = fighter()
            char.inventory[1] = priced("stamina", 4)
            assert(Combat.adjacencyGap(char, char.inventory[1]) == nil)
            assert(Combat.adjacencyGap(char, bow()) == nil, "nor is a plain weapon with no ability")
            assert(Combat.adjacencyGap(nil, needsBow()) == nil, "and an absent body is answerable")
        end,
    },

    -- Combat.movementPenalty ---------------------------------------------------------------------
    {
        -- The whole reason the warning has a threshold. -1 Move is the standard price of a coat
        -- (docs/classes.md), so a body in one has bought armor, not made a mistake.
        name = "ONE piece of gear costing Move is armor, not a warning",
        fn = function()
            local char = fighter()
            char.inventory[1] = coat(-1)
            assert(Combat.movementPenalty(char) == nil, "a knight in a coat is a knight in a coat")
            assert(Character.statTotal(char, "movement") == 3, "and the Move row already says 3")
        end,
    },
    {
        name = "a SECOND piece is the warning, and it quotes the whole stack",
        fn = function()
            local char = fighter()
            char.inventory[1], char.inventory[2] = coat(-1), coat(-2)
            local slow = Combat.movementPenalty(char)
            assert(slow, "two pieces charging for Move is the thing this exists to say")
            assert(slow.count == 2 and slow.penalty == -3, "both pieces, summed")
            assert(slow.total == 1, "4 base less 3 bought")
            assert(not slow.immobile, "a body on 1 Move still walks")
            assert(slow.text:find("2") and slow.text:find("-3"),
                "the line quotes the count and the cost -- the total is on the Move row already")
        end,
    },
    {
        -- Combat.moveBudget floors at zero, so past this point the armor is free and the sheet has no
        -- way to show it. This is the one grade of the warning that has to be said out loud.
        name = "a stack that reaches zero says the body cannot move at all",
        fn = function()
            local char = fighter()
            char.inventory[1], char.inventory[2] = coat(-2), coat(-2)
            local slow = Combat.movementPenalty(char)
            assert(slow.total == 0 and slow.immobile, "4 base less 4 bought is planted")
            assert(slow.note and slow.note:find("cannot move"), "and the second line says so in words")

            -- Past the floor: the fourth coat buys nothing, and only the unclamped total knows it.
            char.inventory[3] = coat(-2)
            local worse = Combat.movementPenalty(char)
            assert(worse.total == -2 and worse.immobile,
                "the reading is unclamped where Combat.moveBudget floors -- which is the whole point: "
                .. "the budget cannot tell -4 from 0, so the warning has to")
        end,
    },
    {
        -- The threshold is on the COUNT, but immobility outranks it: one heavy plate on a slow body
        -- plants it, and a warning that hid the worst case behind a count would be worse than none.
        name = "one piece that plants the body is still said",
        fn = function()
            local char = fighter()
            char.stats.movement = 2
            char.inventory[1] = coat(-2)
            local slow = Combat.movementPenalty(char)
            assert(slow and slow.count == 1 and slow.immobile, "one plate, and nowhere to walk")
            assert(slow.text:find("1 piece of gear costs"), "and it counts in the singular")
        end,
    },
    {
        name = "gear that gives Move back is weighed, and clears the warning it was carrying",
        fn = function()
            local char = fighter()
            char.inventory[1], char.inventory[2] = coat(-1), coat(-1)
            assert(Combat.movementPenalty(char), "two coats warn")
            char.inventory[2] = nil
            assert(Combat.movementPenalty(char) == nil,
                "and taking one off clears it -- a warning that outlives the fix is worse than none")

            -- A boot that ADDS Move is not one of the pieces charging for it, but its points still count
            -- toward whether the body can walk.
            char.inventory[2], char.inventory[3] = coat(-2), { id = "test_boots", name = "Test Boots",
                type = "armor", bonus = { movement = 2 } }
            local slow = Combat.movementPenalty(char)
            assert(slow.count == 2 and slow.penalty == -3, "the boot is not charging, so it is not counted")
            assert(slow.total == 3 and not slow.immobile, "but its +2 is in the walk, so the body is fine")
        end,
    },
    {
        name = "a body carrying nothing that costs Move has nothing to warn about",
        fn = function()
            local char = fighter()
            char.inventory[1] = bow()
            assert(Combat.movementPenalty(char) == nil)
            assert(Combat.movementPenalty(nil) == nil, "and an absent body is answerable")
        end,
    },
}
