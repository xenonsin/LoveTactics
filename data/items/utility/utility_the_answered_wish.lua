-- THE ANSWERED WISH: what a company carries out of a lamp room, and it is the lamp's own rule.
--
-- A Fire Elemental spends its whole fight charging you for reaching it -- whoever damages it catches fire, at
-- any range, by any means (data/characters/character_fire_elemental.lua). This is that, handed over. Nothing
-- else in the game bills an attacker for the act of attacking: the game's retaliations are all reflexes
-- with a reach gate and a stamina price behind them (Antler Toss, Shield Shove, Downdraft), and this is
-- the property those three are imitations of.
--
-- THE RIFT SELLS YOU THE TRICK, which is the ordering the Barrow Lord's Marrowlight argues in full: a
-- rule like this is a strange thing to be handed cold at a counter and an ordinary thing to be handed
-- by the corpse of the thing that spent a fight doing it to you.
--
-- WHY IT SHELVES AT THE SENTINEL, and this is the most interesting thing about it. "Takes the hits meant
-- for someone else. Attacks aimed at an adjacent ally are redirected onto you instead"
-- (data/classes/sentinel.lua) -- a house whose entire stock is about COLLECTING blows, which until now
-- has been a pure cost paid for somebody else's safety. Put this in the same grid and every redirected
-- swing lights the swinger: the more of the party's incoming the bearer eats, the more of the enemy line
-- is on fire. That is a synergy a player assembles out of one shelf's own stock rather than a rung
-- handed out ([[a-pair-is-a-synergy-not-a-tier]] is the shape), and it is why the piece is worth a cell
-- on a body that was already going to be hit.
--
-- `class` IS THE VENDOR SHELF AND NEVER AN EQUIP GATE (docs/classes.md). The Sentinel is where being
-- hit on purpose is written down, not who is allowed to carry this -- and on a body that is trying not
-- to be hit at all it is nearly dead weight, which is the honest shape of the bargain.
--
-- WHAT PACES IT IS BURN'S OWN REFRESH rather than a cooldown. Status.apply refreshes a duration instead
-- of stacking it, so a rank of four all swinging at the bearer in one round leaves four bodies each
-- carrying one burn, not a pile -- the rule bills every attacker once and never compounds. The Fire Elemental
-- is balanced by the same fact read from the other side (trait_wanting_costs).
--
-- FOUND IN THE RIFT, NOT DEALT OVER A COUNTER (docs/shelf.md): no `price`, so a counter stocks it only
-- once the class has climbed to its rung.
return {
    name = "The Answered Wish",
    description = "Whoever damages you catches fire.",
    flavor = "Somebody knelt and paid for this to be lit, and then went away, and it is still burning.",
    sprite = "assets/items/the_answered_wish.png",
    type = "utility",
    tags = { "charm", "fire" },
    class = "sentinel",
    -- Rung 6, which was an empty one on this shelf. The ladder wants a RAMP -- one ware per rung before
    -- any surplus is spread, fewer at the front than at the deep end (tools/shelf_curve.lua,
    -- tests/unlock_ladder_spec.lua) -- so a find drops into a gap rather than onto rung 4, which the
    -- Sentinel already deals three wares from.
    unlockLevel = 8,
    traits = { "trait_wanting_costs" },
}
