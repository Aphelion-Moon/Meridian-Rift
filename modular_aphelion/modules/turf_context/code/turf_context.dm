/**
 * Restores saved turf listeners without reviving deleted or withdrawn subscriptions.
 * The saved lookup predates the new turf's Initialize(), which can delete its contents while
 * their former signal table is temporarily unavailable. Live subscriptions still carry over.
 */
/turf/proc/restore_surviving_turf_listeners(list/saved_lookup)
	for(var/signal in saved_lookup.Copy())
		var/subscribers = saved_lookup[signal]
		if(!islist(subscribers))
			var/datum/single_subscriber = subscribers
			var/list/single_handlers = single_subscriber?._signal_procs?[src]
			// ChangeTurf restores the turf's own outgoing signal table after this lookup.
			if(QDELETED(single_subscriber) || (single_subscriber != src && !single_handlers?[signal]))
				saved_lookup -= signal
			continue
		var/list/subscriber_list = subscribers
		var/list/survivors = subscriber_list.Copy()
		for(var/datum/subscriber as anything in subscriber_list)
			var/list/handlers = subscriber?._signal_procs?[src]
			if(QDELETED(subscriber) || (subscriber != src && !handlers?[signal]))
				survivors -= subscriber
		switch(length(survivors))
			if(0)
				saved_lookup -= signal
			if(1)
				saved_lookup[signal] = survivors[1]
			else
				saved_lookup[signal] = survivors
	if(length(saved_lookup))
		LAZYOR(_listen_lookup, saved_lookup)

/** Drops the listener side of a subscription while a replacing turf's lookup is unavailable. */
/datum/proc/unregister_replaced_turf_signals(turf/target, sig_type_or_types)
	var/list/handlers = _signal_procs?[target]
	if(!handlers)
		return
	handlers -= sig_type_or_types
	if(!length(handlers))
		_signal_procs -= target
