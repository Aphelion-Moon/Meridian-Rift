/// Maximum queued identities; also bounds map/array resizing costs.
#define MEMORY_NODE_LIMIT 2048
/// Maximum observations, including primitive slots that produce no graph edge.
#define MEMORY_WORK_LIMIT 65536
/// Maximum indexed slots in any one ordinary list or datum vars view.
#define MEMORY_SLOT_LIMIT 4096
/// Small alists may be copied atomically; larger alists are count-only.
#define MEMORY_ALIST_LIMIT 32
/// Transport bytes, with a separately reserved footer.
#define MEMORY_OUTPUT_LIMIT 2097152

/** One capture-scoped identity. The strong reference prevents reuse until cleanup. */
/datum/memory_capture_entry
	/// Observed object, never serialized directly.
	var/value
	/// Capture-scoped identifier.
	var/id
	/// Raw engine reference, used only internally.
	var/reference
	/// Observation category.
	var/kind
	/// Type name, never arbitrary datum text.
	var/type_name
	/// Breadth-first discovery depth.
	var/depth
	/// Initial length (or number of variable names).
	var/size
	/// Next slot to inspect.
	var/cursor = 1
	/// Bounded alist key copy; only for small alists.
	var/list/keys
	/// Corresponding values, kept separate to preserve numeric and list keys.
	var/list/values
	/// Ordinary numeric/null slots have no ambiguous associative keys.
	var/numeric_slots = 0
	/// Non-null associations observed; null versus absent remains unknown.
	var/associations = 0

/**
 * Bounded, weakly consistent observation of selected roots, not a heap census.
 * All work, including output and reference release, runs through advance(). No sleeps,
 * world iteration, icon metadata inspection, GC changes, or arbitrary value serialization.
 */
/datum/memory_capture
	/// Transport path chosen by the integration, not by imported or gameplay content.
	var/output_path
	/// Public state; cleanup runs even while paused or after timeout.
	var/state = "header"
	/// Terminal result, separate from the cleanup state.
	var/result = "complete"
	/// First stopping reason.
	var/reason
	/// One bounded header supplied by the integration.
	var/list/provenance
	/// Selected roots (at most 16), released as each is discovered.
	var/list/roots = list()
	/// Stable root labels.
	var/list/root_names = list()
	/// Capture-local identity table; never a cross-capture reference registry.
	var/list/identities = list()
	/// Breadth-first queue retaining at most node_limit identities.
	var/list/entries = list()
	/// At most four structural records from one traversal step; no gameplay values.
	var/list/records = list()
	/// Edges awaiting output reserve capacity without counting as successful writes.
	var/queued_edges = 0
	/// Peak bounded record queue, excluding collector data from gameplay totals.
	var/record_peak = 0
	/// Instrumentation separates encoding and synchronous file writes.
	var/encoding_ms = 0
	var/writing_ms = 0
	var/write_calls = 0
	var/worst_writes_per_step = 0
	/// Next root.
	var/root_cursor = 1
	/// Next queue entry.
	var/entry_cursor = 1
	/// Total emitted nodes.
	var/node_count = 0
	/// Total emitted edges (multiple observed owners are preserved).
	var/edge_count = 0
	/// Number of bounded step operations.
	var/work = 0
	/// Transport record sequence, including header and footer.
	var/sequence = 0
	/// UTF-8 bytes of successful writes.
	var/output_bytes = 0
	/// Number of encountered length changes; equal-length mutations remain invisible.
	var/mutations = 0
	/// Deleted or queued-for-deletion targets encountered.
	var/deletions = 0
	/// Number of excluded/unavailable fields or values.
	var/skipped = 0
	/// Load backoffs, recorded by the scheduler.
	var/backoffs = 0
	/// Capture start in world deciseconds.
	var/started_at
	/// Worst uninterrupted step, including encoding and file I/O.
	var/worst_atomic_ms = 0
	/// Total measured tick work, including cleanup and footer writes.
	var/total_ms = 0
	/// Maximum measured total work in a single tick.
	var/worst_tick_ms = 0
	/// Tick observations; bounded histogram, not an ever-growing sample list.
	var/list/tick_histogram = list(0, 0, 0, 0, 0, 0)
	/// A tick may be serviced at most once, even if the subsystem is resumed.
	var/last_tick = -1
	/// Current tick's start, allowing a footer in the first tick to report its cost.
	var/tick_start_usage
	/// Opt-in pause; duration still expires while paused.
	var/paused = FALSE
	/// Absolute caps may be reduced by tests/operators, never raised by integration.
	var/node_limit = MEMORY_NODE_LIMIT
	/// Maximum total bounded steps before partial cleanup.
	var/work_limit = MEMORY_WORK_LIMIT
	/// Maximum emitted edges; independent from unique identity count.
	var/edge_limit = 8192
	/// Per-container indexed reads; can be reduced by configuration.
	var/slot_limit = MEMORY_SLOT_LIMIT
	/// Maximum duration, including paused time, in deciseconds.
	var/duration_limit = 600
	/// Maximum traversal depth; depth-limited nodes remain observable leaves.
	var/depth_limit = 8
	/// Configurable output limit; footer reserves an additional 4096 bytes.
	var/output_limit = MEMORY_OUTPUT_LIMIT
	/// Provisional per-tick target; atomic operations cannot be preempted.
	var/budget_ms = 1
	/// Fractional tick allowance; production integration never raises the 2% default.
	var/tick_fraction = 0.02
	/// Successful node records, distinct from discovered identities on failed writes.
	var/emitted_nodes = 0
	/// Number of truncations/unsupported traversals; never extrapolated.
	var/truncations = 0
	/// Measured phase cost; footer's own write is reported by runtime harnesses.
	var/list/phase_ms = list("header" = 0, "roots" = 0, "walk" = 0, "output" = 0, "cleanup" = 0, "footer" = 0)

/** Initialize one job. Roots are added individually, outside any global census. */
/datum/memory_capture/New(path, list/metadata)
	output_path = path
	provenance = metadata
	started_at = world.time

/** Register a deliberately selected, named root. */
/datum/memory_capture/proc/add_root(value, label)
	if(length(roots) >= 16 || state != "header")
		return FALSE
	roots += list(value)
	root_names += label
	return TRUE

/** Begin incremental release on every terminal path. */
/datum/memory_capture/proc/finish(status, why)
	if(state == "done" || state == "footer" || state == "draining" || state == "cleanup")
		return
	result = status
	reason = why
	// A cancellation before the first flush still needs its queued header.
	var/list/first_record = length(records) ? records[1] : null
	if(!sequence && first_record?["record"] == "header")
		records.Cut(2)
	else
		records.Cut()
	queued_edges = 0
	state = "cleanup"

/** Queue structural metadata; advance drains it before inspecting another slot. */
/datum/memory_capture/proc/emit(list/record, footer = FALSE)
	records += list(record)
	if(record["record"] == "edge")
		queued_edges++
	record_peak = max(record_peak, length(records))

/** Write one record per bounded step. text2file remains non-preemptible. */
/datum/memory_capture/proc/flush_record()
	var/list/record = records[1]
	records.Cut(1, 2)
	var/kind = record["record"]
	var/footer = kind == "footer"
	if(kind == "edge")
		queued_edges--
	sequence++
	record["sequence"] = sequence
	var/start_usage = world.tick_usage
	var/encoded = json_encode(record)
	encoding_ms += max(0, (world.tick_usage - start_usage) * world.tick_lag)
	var/byte_count = length(encoded) + 1
	if(byte_count > 4096 || output_bytes + byte_count > output_limit + (footer ? 4096 : 0))
		sequence--
		finish("partial", "output_limit")
		if(footer)
			result = "error"
			reason = "footer_output_limit"
			state = "done"
		return FALSE
	start_usage = world.tick_usage
	write_calls++
	var/written = text2file(encoded, output_path)
	writing_ms += max(0, (world.tick_usage - start_usage) * world.tick_lag)
	if(!written)
		sequence--
		finish("error", "write_failed")
		result = "error"
		reason = "write_failed"
		if(footer)
			result = "error"
			reason = "footer_write_failed"
			state = "done"
		return FALSE
	output_bytes += byte_count
	if(kind == "node")
		emitted_nodes++
	else if(kind == "edge")
		edge_count++
	else if(footer)
		state = "done"
	return TRUE

/** Record identity and edge without serializing values or association key contents. */
/datum/memory_capture/proc/observe(value, owner, field, depth)
	if(edge_count + queued_edges >= edge_limit)
		finish("partial", "edge_limit")
		return
	var/kind
	var/type_name
	var/size
	if(istype(value, /alist))
		kind = "alist"
		type_name = "/alist"
		size = length(value)
	else if(islist(value))
		kind = "list"
		type_name = "/list"
		size = length(value)
	else if(isicon(value) || istype(value, /image) || istype(value, /mutable_appearance))
		kind = "resource"
		type_name = isicon(value) ? "/icon-or-resource" : "/appearance"
	else if(istype(value, /datum))
		var/datum/target = value
		if(istype(target, /datum/memory_capture) || istype(target, /datum/memory_capture_entry) || MEMORY_CAPTURE_EXCLUDED(target))
			skipped++
			return
		if(MEMORY_CAPTURE_DELETED(target))
			deletions++
			return
		type_name = "[target.type]"
		kind = istype(target, /atom) ? "atom" : "datum"
		size = length(target.vars)
	else
		// Primitive values and static files have no supported allocation identity.
		return
	var/reference = "\ref[value]"
	var/datum/memory_capture_entry/entry = identities[reference]
	if(entry && entry.value != value)
		// A hard-deleted datum can be replaced at the same ref. Never merge its successor.
		entry = null
		deletions++
	if(!entry)
		if(node_count >= node_limit)
			finish("partial", "node_limit")
			return
		entry = new
		entry.value = value
		entry.reference = reference
		node_count++
		entry.id = node_count
		entry.kind = kind
		entry.type_name = type_name
		entry.depth = depth
		entry.size = size
		identities[reference] = entry
		entries += entry
		emit(list("record" = "node", "id" = entry.id, "kind" = kind, "type" = type_name, "length" = size > 16777215 ? null : size, "depth" = depth, "observed_ds" = world.time - started_at))
	if(state == "cleanup")
		return
	emit(list("record" = "edge", "owner" = owner, "target" = entry.id, "field" = field, "observed_ds" = world.time - started_at))

/** Do exactly one bounded unit. All nested containers are queued, never recursed. */
/datum/memory_capture/proc/advance()
	if(length(records))
		flush_record()
		return
	if(state == "header" || (state == "cleanup" && !sequence && provenance))
		emit(list("record" = "header", "schema_version" = 1, "collector_version" = "1.1", "provenance" = provenance, "scope" = "selected-roots-v1", "roots" = root_names, "settings" = list("nodes" = node_limit, "edges" = edge_limit, "work" = work_limit, "slots" = slot_limit, "alist_copy" = MEMORY_ALIST_LIMIT, "depth" = depth_limit, "duration_ds" = duration_limit, "output_bytes" = output_limit, "budget_ms" = budget_ms, "tick_fraction" = tick_fraction)))
		provenance = null
		if(state != "cleanup")
			state = "roots"
		return
	if(state == "roots")
		if(root_cursor > length(roots))
			state = "walk"
			return
		observe(roots[root_cursor], 0, root_names[root_cursor], 0)
		roots[root_cursor] = null
		root_cursor++
		return
	if(state == "walk")
		if(entry_cursor > length(entries))
			finish(truncations ? "partial" : "complete", truncations ? "bounded_scope" : null)
			return
		var/datum/memory_capture_entry/entry = entries[entry_cursor]
		var/value = entry.value
		var/datum/datum_value = istype(value, /datum) ? value : null
		if(isnull(value) || (datum_value && MEMORY_CAPTURE_DELETED(datum_value)))
			deletions++
			entry_cursor++
			return
		if(entry.depth >= depth_limit || entry.kind == "resource")
			truncations++
			entry_cursor++
			return
		if(entry.kind == "alist" && entry.size > MEMORY_ALIST_LIMIT)
			truncations++
			entry_cursor++
			return
		if(entry.kind == "alist" && !entry.keys)
			if(length(value) > MEMORY_ALIST_LIMIT)
				mutations++
				truncations++
				entry_cursor++
				return
			entry.keys = list()
			entry.values = list()
			for(var/key, associated_value in value)
				entry.keys += list(key)
				entry.values += list(associated_value)
			return
		var/list/slots
		if(entry.kind == "list")
			slots = value
		else if(entry.kind == "alist")
			slots = entry.keys
		else
			var/datum/target = value
			slots = target.vars
		var/current_length = length(slots)
		if(current_length != entry.size)
			mutations++
			// Stop this object instead of restarting or copying a shifting collection.
			truncations++
			entry_cursor++
			return
		if(entry.cursor > min(entry.size, slot_limit))
			if(entry.size > slot_limit)
				truncations++
			emit(list("record" = "node_end", "id" = entry.id, "scanned" = entry.cursor - 1, "numeric_slots" = entry.numeric_slots, "non_null_associations" = entry.associations, "fully_scanned" = entry.size <= slot_limit, "observed_ds" = world.time - started_at))
			entry_cursor++
			return
		var/index = entry.cursor
		entry.cursor++
		var/key = slots[index]
		if(entry.kind == "list" || entry.kind == "alist")
			if(isnum(key) || isnull(key))
				entry.numeric_slots++
			observe(key, entry.id, "slot:[index]:key", entry.depth + 1)
			if(state == "cleanup")
				return
			if(entry.kind == "alist")
				observe(entry.values[index], entry.id, "slot:[index]:value", entry.depth + 1)
			else if(!isnum(key) && !isnull(key))
				// Numeric ordinary entries are positions, never associative keys.
				if(!isnull(slots[key]))
					entry.associations++
				observe(slots[key], entry.id, "slot:[index]:value", entry.depth + 1)
		else
			// Skip special collections BEFORE reading: area.contents can itself scan world.
			if(key in list("vars", "contents", "locs", "vis_contents", "vis_locs", "overlays", "underlays", "filters", "screen", "images", "verbs", "group", "client", "key", "ckey", "weak_reference"))
				skipped++
				return
			observe(slots[key], entry.id, copytext(key, 1, 193), entry.depth + 1)
		return
	if(state == "cleanup")
		if(length(roots))
			roots.Cut(length(roots), length(roots) + 1)
			return
		if(length(entries))
			var/datum/memory_capture_entry/entry = entries[length(entries)]
			if(length(entry.keys))
				entry.keys.Cut(length(entry.keys), length(entry.keys) + 1)
				entry.values.Cut(length(entry.values), length(entry.values) + 1)
				return
			identities -= entry.reference
			entry.value = null
			entries.Cut(length(entries), length(entries) + 1)
			return
		root_names = null
		state = "footer"
		return
	if(state == "footer")
		var/current_ms = isnull(tick_start_usage) ? 0 : max(0, (world.tick_usage - tick_start_usage) * world.tick_lag)
		var/list/footer_histogram = tick_histogram.Copy()
		if(!isnull(tick_start_usage))
			var/bucket = current_ms <= 0.1 ? 1 : (current_ms <= 0.25 ? 2 : (current_ms <= 0.5 ? 3 : (current_ms <= 1 ? 4 : (current_ms <= 2 ? 5 : 6))))
			footer_histogram[bucket]++
		emit(list("record" = "footer", "status" = result, "reason" = reason, "nodes" = emitted_nodes, "edges" = edge_count, "work" = work, "duration_ds" = world.time - started_at, "mutations" = mutations, "deletions" = deletions, "skipped" = skipped, "truncations" = truncations, "backoffs" = backoffs, "total_ms_before_footer" = total_ms + current_ms, "worst_tick_ms_before_footer" = max(worst_tick_ms, current_ms), "worst_atomic_ms_before_footer" = worst_atomic_ms, "tick_histogram_before_footer" = footer_histogram, "phase_ms_before_footer" = phase_ms, "encoding_ms_before_footer" = encoding_ms, "writing_ms_before_footer" = writing_ms, "write_calls_before_footer" = write_calls, "worst_writes_per_step" = worst_writes_per_step, "record_queue_peak" = record_peak, "retained_references" = length(entries) + length(roots)), TRUE)
		state = "draining"

/** Service once per tick, with a shared budget across every phase. */
/datum/memory_capture/proc/tick()
	if(state == "done" || last_tick == world.time)
		return
	last_tick = world.time
	if(world.time - started_at > duration_limit)
		finish("partial", "duration_limit")
	var/cleaning = state == "cleanup" || state == "footer" || state == "draining"
	if(!cleaning && (paused || world.tick_usage > 50))
		backoffs++
		return
	var/start_usage = world.tick_usage
	tick_start_usage = start_usage
	var/limit_ms = min(budget_ms, world.tick_lag * 100 * tick_fraction)
	var/steps = 0
	while(state != "done" && steps < 32)
		var/atomic_start = world.tick_usage
		var/phase = length(records) ? "output" : state
		var/writes_before = write_calls
		try
			advance()
		catch
			finish("error", "runtime_exception")
		work++
		steps++
		worst_writes_per_step = max(worst_writes_per_step, write_calls - writes_before)
		var/atomic_ms = max(0, (world.tick_usage - atomic_start) * world.tick_lag)
		phase_ms[phase] += atomic_ms
		worst_atomic_ms = max(worst_atomic_ms, atomic_ms)
		if(atomic_ms > limit_ms)
			finish("partial", "atomic_budget_exceeded")
		if(work >= work_limit)
			finish("partial", "work_limit")
		if((world.tick_usage - start_usage) * world.tick_lag >= limit_ms || world.tick_usage >= 60)
			break
	var/elapsed_ms = max(0, (world.tick_usage - start_usage) * world.tick_lag)
	total_ms += elapsed_ms
	worst_tick_ms = max(worst_tick_ms, elapsed_ms)
	var/bucket = elapsed_ms <= 0.1 ? 1 : (elapsed_ms <= 0.25 ? 2 : (elapsed_ms <= 0.5 ? 3 : (elapsed_ms <= 1 ? 4 : (elapsed_ms <= 2 ? 5 : 6))))
	tick_histogram[bucket]++
	tick_start_usage = null
