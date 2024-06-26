#define COMSIG_SPELL_TOUCH_CAN_HIT "spell_touch_can_hit"

/**
 * A preset component for touch spells that use mana
 *
 * These spells require mana to activate (channel into your hand)
 * but does not expend mana until you actually touch someone with it.
 */
/datum/component/uses_mana/story_spell/touch
	can_transfer = FALSE

/datum/component/uses_mana/story_spell/touch/Initialize(...)
	if (!istype(parent, /datum/action/cooldown/spell/touch))
		return COMPONENT_INCOMPATIBLE

	return ..()

/datum/component/uses_mana/story_spell/touch/RegisterWithParent()
	RegisterSignal(parent, COMSIG_SPELL_BEFORE_CAST, PROC_REF(handle_precast))
	RegisterSignal(parent, COMSIG_SPELL_TOUCH_CAN_HIT, PROC_REF(can_touch))
	RegisterSignal(parent, COMSIG_SPELL_TOUCH_HAND_HIT, PROC_REF(handle_touch))

/datum/component/uses_mana/story_spell/touch/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_SPELL_BEFORE_CAST)
	UnregisterSignal(parent, COMSIG_SPELL_TOUCH_CAN_HIT)
	UnregisterSignal(parent, COMSIG_SPELL_TOUCH_HAND_HIT)

/datum/component/uses_mana/story_spell/touch/proc/can_touch(
	datum/action/cooldown/spell/touch/source,
	atom/victim,
	mob/living/carbon/caster,
)
	SIGNAL_HANDLER

	if(source.attached_hand)
		return NONE // de-activating, so don't block it

	return can_activate_check(TRUE, caster, victim)

/datum/component/uses_mana/story_spell/touch/proc/handle_touch(
	datum/action/cooldown/spell/touch/source,
	atom/victim,
	mob/living/carbon/caster,
	obj/item/melee/touch_attack/hand,
)
	SIGNAL_HANDLER

	react_to_successful_use(source, victim)

// Override to send a signal we can react to
/datum/action/cooldown/spell/touch/can_hit_with_hand(atom/victim, mob/caster)
	. = ..()
	if(!.)
		return

	if(SEND_SIGNAL(src, COMSIG_SPELL_TOUCH_CAN_HIT, victim, caster) & SPELL_CANCEL_CAST)
		return FALSE

	return TRUE

#undef COMSIG_SPELL_TOUCH_CAN_HIT
