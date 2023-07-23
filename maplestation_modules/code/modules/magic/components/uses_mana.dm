/* Design notes:
* This component designates the parent object as something that "uses mana".
* As such, it should modify the object's behavior at some point to require, consume, or check mana.
* Example: A magic crowbar that requires 5 mana to use it with anything.
* A component created for this crowbar should register the various signals for checking things, such as COMSIG_TOOL_START_USE, or
* COMSIG_ITEM_ATTACK. These should be linked to a proc that checks if the user has enough available mana (not sure how to make this info available with the current setuo)
* and if not, return something that cancels the proc.
* However, if the mana IS sufficient, we should listen for the successful item act signal, and react by, say, subtracting 5 mana from the mana pool provided.
* Not all need to do this, though, some could simply check and no nothing else, or others.
*/
/// Designates the item it's added to as something that "uses mana".
/datum/component/uses_mana
	var/datum/callback/get_mana_callback
	var/datum/callback/activate_check_failure_callback

	var/datum/callback/get_mana_required_callback
	var/datum/callback/get_mana_consumed_callback

	var/datum/callback/get_user_callback

	var/list/datum/attunement/attunements

	var/pre_use_check_comsig
	var/post_use_comsig

/datum/component/uses_mana/Initialize(
	datum/callback/get_mana_callback,
	datum/callback/activate_check_failure_callback,
	pre_use_check_comsig,
	post_use_comsig,
	datum/callback/get_mana_required_callback,
	datum/callback/get_mana_consumed_callback,
	datum/callback/get_user_callback,
	list/datum/attunement/attunements,
)
	. = ..()

	if (isnull(pre_use_check_comsig) || isnull(post_use_comsig))
		return COMPONENT_INCOMPATIBLE

	if (!isatom(parent) && isnull(get_mana_callback))
		return COMPONENT_INCOMPATIBLE

	if (isnull(get_mana_required_callback) && isnull(get_mana_consumed_callback))
		return COMPONENT_INCOMPATIBLE

	src.get_mana_callback = get_mana_callback

	if (isnull(get_mana_to_use()))
		return COMPONENT_INCOMPATIBLE

	src.activate_check_failure_callback = activate_check_failure_callback
	src.attunements = attunements

	src.get_mana_required_callback = get_mana_required_callback
	src.get_mana_consumed_callback = get_mana_consumed_callback

	src.get_user_callback = get_user_callback

	src.pre_use_check_comsig = pre_use_check_comsig
	src.post_use_comsig = post_use_comsig

/datum/component/uses_mana/RegisterWithParent()
	. = ..()

	RegisterSignal(parent, pre_use_check_comsig, PROC_REF(can_activate_check))
	RegisterSignal(parent, post_use_comsig, PROC_REF(react_to_successful_use))

/datum/component/uses_mana/UnregisterFromParent()
	. = ..()

	UnregisterSignal(parent, pre_use_check_comsig)
	UnregisterSignal(parent, post_use_comsig)

/datum/component/uses_mana/proc/get_mana_to_use()
	if (!isnull(get_mana_callback))
		return get_mana_callback.Invoke()
	var/atom/atom_parent = parent
	return atom_parent.mana_pool

// TODO: Do I need the vararg?
/// Should return the numerical value of mana needed to use whatever it is we're using. Unaffected by attunements.
/datum/component/uses_mana/proc/get_mana_required()
	if (!isnull(get_mana_required_callback))
		return get_mana_required_callback.Invoke()
	return get_mana_consumed()

/datum/component/uses_mana/proc/get_mana_consumed()
	return get_mana_consumed_callback.Invoke()

/// Should return TRUE if the total adjusted mana of all mana pools surpasses get_mana_required(). FALSE otherwise.
/datum/component/uses_mana/proc/is_mana_sufficient(list/datum/mana_pool/provided_mana = list(get_mana_to_use), atom/caster)
	var/total_effective_mana = 0

	for (var/datum/mana_pool/iterated_pool as anything in provided_mana)
		total_effective_mana += iterated_pool.get_attuned_amount(attunements, caster)
	if (total_effective_mana > get_mana_required())
		return TRUE

/// The primary proc we will use for draining mana to simulate it being consumed to power our actions.
/datum/component/uses_mana/proc/drain_mana(cost = -get_mana_consumed())

	var/mob/user = get_user_callback.Invoke()

	var/mana_consumed = get_mana_consumed()
	if (!mana_consumed)
		return

	var/datum/mana_pool/pool = get_mana_to_use()

	var/mult = pool.get_overall_attunement_mults(attunements, user)
	var/attuned_cost = (cost * mult)
	cost -= SAFE_DIVIDE(pool.adjust_mana((attuned_cost)), mult)

	if (cost != 0)
		stack_trace("cost: [cost] was not 0 after drain_mana on [src]!")

/// Should be the raw conditional we use for determining if the thing that "uses mana" can actually
/// activate the behavior that "uses mana".
/datum/component/uses_mana/proc/can_activate(atom/caster)
	return is_mana_sufficient(get_mana_to_use(), caster)

/// Wrapper for can_activate(). Should return a bitflag that will be passed down to the signal sender on failure.
/datum/component/uses_mana/proc/can_activate_check(give_feedback = TRUE, atom/caster, ...)
	SIGNAL_HANDLER

	var/list/argss = args.Copy(2)
	var/can_activate = can_activate(arglist(argss)) //doesnt return this + can_activate_check_... because returning TRUE/FALSE can gave bitflag implications
	if (!can_activate)
		return can_activate_check_failure(arglist(args.Copy()))

/// What can_activate_check returns apon failing to activate.
/datum/component/uses_mana/proc/can_activate_check_failure(...)
	SIGNAL_HANDLER
	activate_check_failure_callback?.Invoke(arglist(args))
	return FALSE

/// Should react to a post-use signal given by the parent, and ideally subtract mana, or something.
/datum/component/uses_mana/proc/react_to_successful_use(...)
	SIGNAL_HANDLER

	drain_mana()

	return

