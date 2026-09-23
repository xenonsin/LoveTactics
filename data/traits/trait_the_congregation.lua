-- THE CONGREGATION: a wound meant for her opens in the bodies she has taken instead, shared out whole.
--
-- SHE IS NEVER THE THING YOU ARE HITTING. The rest of this circle answers a blow by deciding where you
-- are standing afterwards -- the Downdraft throws the room off her, the kiss trades tiles with whoever
-- closed. This answers a blow by deciding WHO TOOK IT, which is the allegiance verb pointed at damage
-- rather than at a turn, and it is the reason the Abbess is an elite rather than a large chaff: the
-- company's problem is not reaching her, it is that reaching her costs them one of their own.
--
-- THE WHOLE BLOW, SPLIT, AND NOTHING KEPT BACK. One charmed body takes all of it; three take a third
-- each. So the counterplay is not "kill through it" -- it is the stratum's own, stated at the top of
-- the Lust entry in models/descent.lua and now with real teeth: **cut the one doing it, or cure your
-- own.** Cure/Panacea frees the victim and the split has one fewer place to land; the charm runs out on
-- its own clock (ten ticks, about two turns); and the moment she falls, everyone she held comes home.
--
-- EACH SHARE IS RE-THROWN AS A REAL BLOW. It re-enters Combat.dealFlatDamage on the charmed body, so
-- that body's own armour, resists, barrier and reflexes all apply -- a share landing on the anvil she
-- took is mitigated like anything else the anvil is hit by. Which also means the arithmetic is honest
-- in the direction that matters: splitting a blow across a well-armoured party member is not a clean
-- transfer, it is a transfer that the party's own gear then answers.
--
-- ...AND A SHARE NEVER FALLS BELOW ONE. Floor division across three bodies would silently round a
-- small hit away to nothing and make her immune to chip damage, which is the opposite of the rule: she
-- is not warded, she is HIDING, and hiding behind somebody does not stop the blow existing.
--
-- IT SITS BESIDE THE GUARDIAN REDIRECT, WHICH IS THE SAME THING POINTED THE OTHER WAY. An Oathward
-- knight steps in front of an ally it chose to cover; this makes somebody take a blow for her who did
-- not choose anything. Same seam in Combat.dealFlatDamage, same re-entry, same reason: whatever ends up
-- eating the hit should eat it with all of its own machinery attached.
--
-- AND IT IS NOT IN THE FORECAST, deliberately and by precedent. The hover preview reads
-- Combat.mitigatedDamage against the body under the cursor; the guardian redirect is not in it either,
-- for the same reason -- a redirect is a fact about the board at the instant of the blow, not a
-- property of the target. The player is told by the LOG line and by the health bar that moved, which is
-- how they find out an Oathward is standing there too.
--
-- SUNDER SWITCHES IT OFF, for free, and that is worth knowing at the counter as well as on this body:
-- Trait.flag refuses every flagged rule on a body holding `status_sundered`. A company that silences
-- her is hitting her directly for as long as it holds.
return {
    name = "The Congregation",
    description = "Damage dealt to you is split among the foes you have Charmed.",
    sharesWounds = true,
}
