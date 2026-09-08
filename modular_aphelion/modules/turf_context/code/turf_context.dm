/**
 * Restores saved turf listeners without reviving subscribers deleted during replacement construction.
 * The saved lookup predates the new turf's Initialize(), which can delete its contents while
 * their former signal table is temporarily unavailable. Live subscriptions still carry over.
 */
/turf/proc/restore_surviving_turf_listeners(list/saved_lookup)
	for(var/signal in saved_lookup.Copy())
		var/subscribers = saved_lookup[signal]
		if(!islist(subscribers))
			var/datum/single_subscriber = subscribers
			if(QDELETED(single_subscriber))
				saved_lookup -= signal
			continue
		var/list/subscriber_list = subscribers
		var/list/survivors = subscriber_list.Copy()
		for(var/datum/subscriber as anything in subscriber_list)
			if(QDELETED(subscriber))
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
