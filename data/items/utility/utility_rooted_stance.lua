-- The Rooted Stance: the Bastion's drilled footing, which is not a trick and not an enchantment -- it
-- is the several years it takes to stop being moveable. One of the four named immunities (see
-- data/items/utility/utility_deadhand_grip.lua for the family).
--
-- It refuses Stun alone, and is the most expensive of the four for it. Stun is the strongest debuff in
-- the game -- it takes the turn AND suppresses every reaction the unit would have thrown
-- (Status.disablesReactions, read across all of models/trait.lua), so a stunned knight is not merely
-- idle, it has stopped being a wall. An item that switches that off is worth rank 4 on its own, and
-- pairing it with anything would have made it the only defensive utility anybody buys.
--
-- Frozen is deliberately NOT included, though it is the other hard control and shares the flag. Two
-- reasons, and the second is the real one: Frozen is the mage's, and its counterplay is already
-- authored in the other direction (a Frozen body is `vulnerable` to crush and fire -- shatter it), so
-- an immunity would be answering a question that already has a better answer. And an item that voided
-- both hard controls at once would leave hard control with no purchase on a prepared party at all,
-- which is a worse game than one where you have to pick which one you are afraid of.
--
-- WHY THE KNIGHT'S: sloth's shelf is the one that "does not kill you, it decides where you stand"
-- (docs/classes.md). The mirror of that is a knight nobody else gets to decide anything about, and the
-- Bastion selling immovability to its own is the shelf talking about itself.
return {
    name = "Rooted Stance",
    description = "Drilled past the point of being moveable: immune to Stun.",
    flavor = "Not a trick and not an enchantment. Several years, mostly spent standing still on purpose.",
    sprite = "assets/items/rooted_stance.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    price = 620,
    repRank = 4,
    statusImmunity = { "status_stun" },
    -- A token of the drill itself, so the slot is not literally empty in a fight with no stuns in it.
    -- Defense rather than health: the stance is a way of standing, and that is what it improves.
    bonus = { defense = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6 } },
}
