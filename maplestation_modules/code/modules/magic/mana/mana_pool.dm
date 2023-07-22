#define MANA_POOL_REPLACE_ALL_ATTUNEMENTS (1<<2)

/* DESIGN NOTES
* This exists because mana will eventually have attunemenents and alignments that will incresae their efficiency in being used
* on spells/by people with corresponding attunements/alignments, vice versa for conflicting.
*
*/

/// An abstract representation of collections of mana, as it's impossible to represent each individual mana unit
/datum/mana_pool
	var/atom/parent = null

	/// As attunements on mana is actually a tangible thing, and not just a preference, mana attunements should never go below zero.
	var/list/datum/attunement/attunements

	/// In vols
	var/amount
	var/maximum_mana_capacity
	/// The threshold at which mana begins decaying exponentially.
	// TODO: convert to some kind of list for multiple softcaps?
	var/softcap
	var/exponential_decay_divisor

	/// The rate at which we can give mana to any given mana pool
	var/max_donation_rate
	var/donation_budget_this_tick

	/// List of (mob -> transfer rate)
	var/list/datum/mana_pool/transfer_rates = list()
	/// List of (mana_pool -> max mana we will give)
	var/list/datum/mana_pool/transfer_caps = list()
	/// List of mana_pools we are transferring mana to
	var/list/datum/mana_pool/transferring_to = list()
	/// List of mana_pools transferring to us
	var/list/datum/mana_pool/transferring_from = list()
	/// Assoc list of (mana_pool -> times to skip), used mostly in [start_transfer]
	var/list/datum/mana_pool/skip_transferring = list()

	/// If true, if no cap is specified, we only go up to the softcap of the target when transferring
	var/transfer_default_softcap

	/// The natural regen rate, detached from transferrals.
	var/ethereal_recharge_rate

	var/intrinsic_recharge_sources = MANA_ALL_LEYLINES

	var/discharge_destinations = MANA_ALL_LEYLINES
	var/discharge_method = MANA_DISCHARGE_SEQUENTIAL
	/// The attunements our natural recharge will use
	var/list/datum/attunement/attunements_to_generate

/datum/mana_pool/New(maximum_mana_capacity,
					softcap,
					max_donation_rate,
					exponential_decay_divisor = BASE_MANA_EXPONENTIAL_DIVISOR,
					ethereal_recharge_rate = 0,
					attunements = GLOB.default_attunements.Copy(),
					attunements_to_generate = null,
					transfer_default_softcap = TRUE,
					amount = maximum_mana_capacity
)
	. = ..()

	src.maximum_mana_capacity = maximum_mana_capacity
	src.exponential_decay_divisor = exponential_decay_divisor
	src.softcap = softcap
	src.max_donation_rate = max_donation_rate
	src.ethereal_recharge_rate = ethereal_recharge_rate
	src.attunements = attunements
	src.attunements_to_generate = attunements_to_generate
	src.transfer_default_softcap = transfer_default_softcap
	src.amount = amount

	update_intrinsic_recharge()

	START_PROCESSING(SSmagic, src)

/datum/mana_pool/Destroy(force, ...)
	attunements = null
	attunements_to_generate = null

	QDEL_NULL(transfer_rates)
	QDEL_NULL(transfer_caps)
	QDEL_NULL(transferring_to)
	QDEL_NULL(skip_transferring)
	QDEL_NULL(transferring_from) // we already have a signal registered, so if we qdel we stop transfers

	STOP_PROCESSING(SSmagic, src)
	return ..()

// order of operations is as follows:
// 1. we recharge
// 2. we transfer mana
// 3. we discharge excess mana
/datum/mana_pool/process(seconds_per_tick)

	donation_budget_this_tick = max_donation_rate

	if (ethereal_recharge_rate != 0)
		adjust_mana(ethereal_recharge_rate * seconds_per_tick, attunements_to_generate)

	for (var/datum/mana_pool/iterated_pool as anything in transferring_to)
		if (!can_transfer(iterated_pool))
			transferring_to -= iterated_pool
			skip_transferring -= iterated_pool
			continue

		if (skip_transferring[iterated_pool])
			skip_transferring -= iterated_pool
			continue

		transfer_mana_to(iterated_pool, seconds_per_tick)

	if (amount < softcap)
	// exponential decay
	// exponentially decays amount when amount surpasses softcap, with [exponential_decay_divisor] being the (inverse) decay factor
	// can only decay however much amount we are over softcap
	// imperfect as of now (need to test)
		var/exponential_decay = (max(-((((NUM_E**((amount - softcap)/exponential_decay_divisor)) + 1)) * seconds_per_tick), (softcap - amount)))
		// in desmos: f\left(x\right)=\max\left(\left(\left(-\left(e\right)^{\left(\frac{\left(x-t\right)}{c}\right)}\right)+1\right),\ \left(t-x\right)\right)\ \left\{x\ge t\right\}
		// t=50
		// c=150
		if (discharge_destinations)
			var/list/datum/mana_pool/pools_to_discharge_into = list()
			if (discharge_destinations & MANA_ALL_LEYLINES)
				pools_to_discharge_into += get_accessable_leylines()

			switch (discharge_method)
				if (MANA_DISPERSE_EVENLY)
					// ...
				if (MANA_SEQUENTIAL)
					for (var/datum/mana_pool/iterated_pool as anything in pools_to_discharge_into)
						exponential_decay -= transfer_specific_mana(iterated_pool, -exponential_decay, FALSE)
						if (exponential_decay <= 0)
							break

		adjust_mana(exponential_decay) //just to be safe, in case we have any left over or didnt have a discharge destination

/// Perform a "natural" transfer where we use the default transfer rate, capped by the usual math
/datum/mana_pool/proc/transfer_mana_to(datum/mana_pool/target_pool, seconds_per_tick = 1)
	var/transfer_rate = get_transfer_rate_for(target_pool)

	return transfer_specific_mana(target_pool, transfer_rate * seconds_per_tick)

/// Returns the amount of mana we want to give in a given tick
/datum/mana_pool/proc/get_transfer_rate_for(datum/mana_pool/target_pool)
	var/cached_rate = transfer_rates[target_pool]
	return min((cached_rate ? min(cached_rate, donation_budget_this_tick) : donation_budget_this_tick), get_maximum_transfer_for(target_pool))

/datum/mana_pool/proc/get_maximum_transfer_for(datum/mana_pool/target_pool)
	var/cached_cap = transfer_caps[target_pool]
	return (cached_cap ? cached_cap : (transfer_default_softcap ? target_pool.softcap : target_pool.maximum_mana_capacity))

/datum/mana_pool/proc/transfer_specific_mana(datum/mana_pool/other_pool, amount_to_transfer, decrement_budget = TRUE)
	// ensure we dont give more than we hold and dont give more than they CAN hold
	var/adjusted_amount = min(min(amount_to_transfer, maximum_mana_capacity), (other_pool.maximum_mana_capacity - other_pool.amount))
	// ^^^^ TODO THIS ISNT THA TGOOD I DONT LIKE IT we should instead have remainders returned on adjust mana and plug it into the OTHER adjust mana

	if (decrement_budget)
		donation_budget_this_tick -= amount_to_transfer

	adjust_mana(-adjusted_amount)
	return other_pool.adjust_mana(adjusted_amount, attunements)

/datum/mana_pool/proc/start_transfer(datum/mana_pool/target_pool)
	/*if (target_pool.maximum_mana_capacity <= target_pool.amount)
		return MANA_POOL_FULL*/

	if (!can_transfer(target_pool))
		return MANA_POOL_CANNOT_TRANSFER

	if (target_pool in transferring_to)
		return MANA_POOL_ALREADY_TRANSFERRING

	skip_transferring[target_pool] = TRUE

	transferring_to += target_pool
	target_pool.incoming_transfer_start(src)

	RegisterSignal(target_pool, COMSIG_PARENT_QDELETING, PROC_REF(stop_transfer))
	transfer_mana_to(target_pool)

	return MANA_POOL_TRANSFER_START

/datum/mana_pool/proc/stop_transfer(datum/mana_pool/target_pool)
	SIGNAL_HANDLER

	transferring_to -= target_pool
	target_pool.incoming_transfer_end(src)

	UnregisterSignal(target_pool, COMSIG_PARENT_QDELETING)

	return MANA_POOL_TRANSFER_STOP

/datum/mana_pool/proc/incoming_transfer_start(datum/mana_pool/donator)
	transferring_from += donator

/datum/mana_pool/proc/incoming_transfer_end(datum/mana_pool/donator)
	transferring_from -= donator

// TODO BIG FUCKING WARNING THIS EQUATION DOSENT WORK AT ALL
// Should be fine as long as nothing actually has any attunements
/// The proc used to modify the mana composition of a mana pool. Should modify attunements in proportion to the ratio
/// between the current amount of mana we have and the mana coming in/being removed, as well as the attunements.
/// Mana pools in general will eventually be refactored to be lists of individual mana pieces with unchanging attunements,
/// so this is not permanent.
/// Returns how much of "amount" was used.
/datum/mana_pool/proc/adjust_mana(amount, list/incoming_attunements)

	/*if (src.amount == 0)
		CRASH("src.amount was ZERO in [src]'s adjust_quanity") //why would this happen
		*/
	if (amount == 0)
		return amount

	if (!isnull(incoming_attunements))

		/*var/ratio
		if (src.amount == 0)
			ratio = MANA_POOL_REPLACE_ALL_ATTUNEMENTS
		else
			ratio = amount/src.amount*/

		/*for (var/iterated_attunement as anything in incoming_attunements)
		// equation formed in desmos, dosent work
			attunements[iterated_attunement] += (((incoming_attunements[iterated_attunement]) - attunements[iterated_attunement]) * (ratio/2)) */

	var/result = clamp(src.amount + amount, 0, maximum_mana_capacity)
	. = result - src.amount // Return the amount that was used
	//if (abs(.) > abs(amount))
		// Currently, due to floating point imprecision, leyline recharges always cause this to fire, but honestly its nothing horrible
		// Ill fix it later(?)
		//stack_trace("[.], amount used, has its absolute value more than [amount]'s during [src]'s adjust_mana")
	src.amount = result

/// Returns an adjusted amount of "effective" mana, affected by the attunements.
/// Will always return a minimum of zero and a maximum of the total amount of mana we can give multiplied by the mults.
/datum/mana_pool/proc/get_attuned_amount(list/datum/attunement/incoming_attunements, atom/caster, amount_to_adjust = src.amount)
	var/mult = get_overall_attunement_mults(incoming_attunements, caster)

	return clamp(SAFE_DIVIDE(amount_to_adjust, mult), 0, amount*mult)

/// Returns the combined attunement mults of all entries in the argument.
/datum/mana_pool/proc/get_overall_attunement_mults(list/attunements, atom/caster)
	return get_total_attunement_mult(src.attunements, attunements, caster)

/datum/mana_pool/proc/can_transfer(datum/mana_pool/target_pool)
	SHOULD_BE_PURE(TRUE)

	return TRUE

/datum/mana_pool/proc/update_intrinsic_recharge()
	if (intrinsic_recharge_sources & MANA_ALL_LEYLINES)
		for (var/datum/mana_pool/leyline/entry as anything in get_accessable_leylines())
			entry.start_transfer(src)

#undef MANA_POOL_REPLACE_ALL_ATTUNEMENTS
