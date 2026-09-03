-- Mammonite -- rogue subclass.
-- Signature mechanic: The purse -- gold is a combat resource in BOTH directions. Coin buys damage,
-- tempo and your own skin (Combat.spendPurse); blows and bodies bank more of it (Combat.bounty).
-- Exemplar: the Bank's collections contractor (data/characters/character_mammonite.lua), met as a RECRUIT.
-- Gate: one quest in the rogue (Undercroft) line -- Quarter-End (slot 6), the night the Bank closes its
-- books and hires the player as paid overflow. You learn the trade by working it.
-- A subclass opens no earlier than slot 3: a discipline handed over on a line's first or
-- second quest is not earned advancement, it is a welcome gift.
-- See docs/classes.md and docs/disciplines-plan.md.
--
-- THE NAME is Ragnarok Online's -- Mammonite is the Merchant's signature skill there, which spends the
-- player's own zeny to land a blow, and is the exact mechanic Blood Money is built on. It is also
-- Milton's demon of wealth, already named in docs/story.md ("The Undercroft") as one of the wells greed's
-- summit was drawn from: "eyes forever down on the golden pavement". So the word arrives sourced from
-- inside the fiction rather than imported into it -- and it is not a general's name (greed's is Aurea,
-- the Ever-Owed), so nothing on the board is called it.
--
-- WHY THIS EXISTS AS A SUBCLASS, reversing an earlier call. docs/disciplines-plan.md ruled that "the
-- rogue's purse kit stays base -- the greed identity itself, not a deeper cut of it". That was right
-- about the identity and wrong about the shelf: the kit had grown to eight items with one shared
-- resource nothing else in the game touches, which is not a flavour of rogue, it is a way of playing the
-- whole battle. A player who wants it wants all of it; a player who does not wants none of it. That is
-- what a discipline IS here -- an opt-in bundle with its own growth table -- so the kit reads better as
-- one earned shelf than as eight loose wares the base rogue browses past.
--
-- WHERE THE GATE SITS, and why nothing needed rebalancing to put it there. The kit was already gated in
-- two tiers by quest count: the EARNERS (The Ledger's Due, A Price on the Head, Skimmer's Cut) open
-- across quests 4-7, and the SPENDERS (Blood Money, The Gilded Wound, Grease Palms, The Open Account)
-- all sit at 9 -- i.e. once Aurea is beaten and her art is yours to take. Gating the discipline at slot
-- 6 therefore lands it exactly between the halves: the shelf opens with the income side, and completes
-- with the spending side at the end of the line. Not a single `unlockQuests` moved.
return {
    name    = "Mammonite",
    description = "The purse as a weapon. Gold is a combat resource in both directions: coin buys damage, tempo and your own skin, and every blow you land banks more of it.",
    classes = { "rogue" },
    exemplar = "character_mammonite",
    requiredLevel = { rogue = 6 },
}
