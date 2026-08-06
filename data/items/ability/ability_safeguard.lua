-- Safeguard: change places with an ally, and both of you come out of it braced.
--
-- The Sentinel's verb, and the one its shelf did not have. The discipline's whole idea is the guard
-- redirect -- Oathward and the Martyr's Vow take somebody else's blow onto your own body (see
-- docs/classes.md) -- and every existing item does it by INTERCEPTING damage after the fight has
-- already gone wrong. This does it by moving, before. The mage standing where the axes are about to
-- fall stops standing there, and the knight is standing there instead.
--
-- SWAPPING IS THE RESCUE, and the brace is what stops it being a trade. A bare swap hands the ally
-- safety by handing the knight a beating, which is on-theme and still a bad button -- you would only
-- ever press it when the arithmetic was already lost. Bracing BOTH bodies makes it a play rather than
-- a sacrifice: the ally leaves the danger, the knight arrives in it prepared, and neither half is a
-- consolation prize.
--
-- THE BRACE IS THE CASTER'S OWN DEFENSE, which is the interesting number. Every other ward in the game
-- has a magnitude its item declares; this one reads Combat.flatStat off the knight throwing it, so the
-- brace is worth what the knight is worth. A Sentinel in full plate hands out a real wall; one in a
-- robe hands out a gesture. That makes armour scale a SUPPORT ability, which nothing else here does,
-- and it is the reason to build the character rather than merely buy the item.
--
-- Halved, because it is granted twice. The knight is not lending its defense away -- that is the Given
-- Guard's trick and it costs the lender the wall -- it is bracing two bodies at once, so each gets half
-- of what one would. The floor of 2 keeps it from reading as nothing on a light Sentinel.
--
-- IT GRANTS DEFENDING, the shield stance's own status, rather than a ward of its own. Three reasons and
-- the third is the real one: Defending is the only existing status whose magnitude drives the stat
-- (`magnitudeStat`, which is what lets the number be the caster's rather than the item's -- Aegis has a
-- flat statBonus and would have silently ignored what this passes it); it already means exactly
-- "braced" to a player who has ever pressed Defend; and it lapses at its holder's next turn
-- (status_defending's own onTurnStart), which is precisely one round of cover for each body and needs
-- no duration authored at all. That last is why this ability has no forge curve on its length: there is
-- nothing to lengthen. What the forge buys here is the knight, through their armour.
--
-- ALLY-ONLY and short-ranged: you cannot Safeguard an enemy into your own line, which would be a
-- forced-movement ability wearing a support ability's coat, and the shelf already sells shoves for that
-- (ability_push). Range 2 rather than 1, so it can reach past the body already beside you -- reaching
-- only your neighbour would make it useless in exactly the formation it is for.
--
-- models.combat is required INSIDE the effect, never at file scope. models/item.lua pulls every
-- blueprint through the registry while combat.lua is still loading, so a top-level require here closes
-- the cycle and the whole game fails to boot. Every other blueprint that reads a combat helper does it
-- the same way (ability_reckoning, ability_flurry).
return {
    name = "Safeguard",
    description = "Trade places with an ally. Both of you brace, by a share of your own defense.",
    flavor = "Move. No -- move where I am. That part is not the favour.",
    sprite = "assets/items/ability_safeguard.png",
    type = "ability",
    tags = { "impact" },
    class = "knight",
    discipline = "sentinel", -- deeper cut of the shelf: buyable only once the sentinel gate is cleared
    price = 340,
    unlockQuests = 6,
    activeAbility = {
        target = "ally",
        range = 2,
        speed = 5,
        support = true, -- a rescue, not a strike: it reads green and lands no damage
        cost = { stat = "stamina", amount = 7 },
        effect = function(fx)
            local ally = fx.target
            if not (ally and ally.alive) then return end
            if ally == fx.user or ally.side ~= fx.user.side then return end
            -- Read the knight's defense BEFORE the swap. Nothing about a swap can change it today, but
            -- the brace is a claim about the body throwing it, and reading it first makes that true by
            -- construction rather than by luck.
            local wall = math.max(2,
                math.floor(require("models.combat").flatStat(fx.user, "defense") / 2))
            if not fx.swap(ally) then return end
            fx.applyStatus(fx.user, "status_defending", { magnitude = wall })
            fx.applyStatus(ally, "status_defending", { magnitude = wall })
            fx.log("action", string.format("%s takes the ally's ground.",
                (fx.user.char and fx.user.char.name) or "The sentinel"), fx.user)
        end,
    },
}
