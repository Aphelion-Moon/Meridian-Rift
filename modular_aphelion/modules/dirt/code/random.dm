/// How many twister words the draft stream keeps its state in, and how far ahead the twist reaches (MT19937's N and M).
#define DIRT_DRAFT_WORDS 624
#define DIRT_DRAFT_REACH 397
/// The most of the draft's noise lattice points that SSdirt.lattice keeps before it's emptied, about 41 B each. A mask
/// job keeps the lattice of the general deposit it draws between its pieces, in the field being drawn or in itself
/// (/datum/dirt_mask_job/var/lattice). So each band and direction reads the points the others hashed. The exception is
/// a shape's deposit drawn whole in each direction (dirt_shape_deposit()), where each direction starts afresh. Deposits
/// sample about 540 points each, as measured, though their peak is unmeasured. The queue works one job at a time, so
/// the lattice holds one job's points at a time, about 335 KB at most.
#define DIRT_LATTICE_POINTS 8192
/// The low half of the 32-bit word (`high`, `low`) times the constant (`by_high`, `by_low`), mod 2^32: low * by_low,
/// taken through `low`'s bytes so no product passes 2^24. Pass it variables, because it reads them more than once.
#define DIRT_DRAFT_PRODUCT_LOW(low, by_low) (((((low) & 255) * (by_low)) + (((((low) >> 8) * (by_low)) & 255) << 8)) & 65535)
/// The high half of that product: the low half's carry, then low * by_high and high * by_low mod 2^16, through bytes.
#define DIRT_DRAFT_PRODUCT_HIGH(high, low, by_high, by_low) ((((((((low) & 255) * (by_low)) & 65535) + (((((low) >> 8) * (by_low)) & 255) << 8)) >> 16) + ((((low) & 255) * (by_low)) >> 16) + ((((low) >> 8) * (by_low)) >> 8) + ((((low) & 255) * (by_high)) & 65535) + (((((low) >> 8) * (by_high)) & 255) << 8) + ((((high) & 255) * (by_low)) & 65535) + (((((high) >> 8) * (by_low)) & 255) << 8)) & 65535)

/**
 * A stream of random draws seeded by text, the same on every server and in the reference generator, so a mask drawn
 * here matches the reference's pixel for pixel. The nth draw, counting from 0, is md5("[seed]:[n]") cut to its first
 * six hex digits: a 24-bit integer, which a DM number holds exactly. Mess takes its random draws from it. Under
 * DIRT_DRAFT_EXACT, general deposits take theirs from the draft stream (/datum/dirt_random/draft).
 *
 * Everything built on draws spends them in the reference's order. Never take a draw with rand() or prob(), and never
 * take a modulo with % or %% on something that may come out negative: use DIRT_MODULO.
 */
/datum/dirt_random
	/// The text every draw hashes.
	var/seed
	/// How many draws the stream has made, which is the next draw's number.
	var/draw_count = 0

/**
 * Starts a stream at its first draw.
 *
 * Arguments:
 * - seed: The stream's text, spelled as the reference spells it ("aimed_chest:0"). Seeds are text: a number is written
 *   out in full, which matches the reference for whole numbers only.
 */
/datum/dirt_random/New(seed)
	. = ..()
	src.seed = istext(seed) ? seed : num2text(seed, 12)

/**
 * Returns the next draw, a whole number from 0 to 16777215.
 *
 * The draw's number goes into the hash in full, as the reference writes it, never in scientific notation.
 */
/datum/dirt_random/proc/draw()
	var/digest = md5("[seed]:[num2text(draw_count, 12)]")
	draw_count++
	return hex2num(copytext(digest, 1, 7))

/**
 * Returns the next draw as a fraction from 0 up to 1, never 1.
 */
/datum/dirt_random/proc/random()
	return draw() / 16777216

/**
 * Returns a number from `low` up to `high`, from one draw.
 *
 * Arguments:
 * - low: The smallest result.
 * - high: The bound the result stays under.
 */
/datum/dirt_random/proc/uniform(low, high)
	return low + (high - low) * random()

/**
 * Returns a whole number from 0 up to `count`, never `count`, from one draw.
 *
 * Arguments:
 * - count: How many results there are, a positive whole number.
 *
 * Crashes:
 * - Divides by zero when `count` is 0.
 */
/datum/dirt_random/proc/randrange(count)
	return draw() % count

/**
 * Returns a whole number from `low` to `high`, both included, from one draw.
 *
 * Arguments:
 * - low: The smallest result.
 * - high: The largest result, no less than `low`.
 */
/datum/dirt_random/proc/randint(low, high)
	return low + randrange(high - low + 1)

/**
 * Returns one of `options`, from one draw.
 *
 * Arguments:
 * - options: The list to pick from.
 *
 * Crashes:
 * - Divides by zero when `options` is empty.
 */
/datum/dirt_random/proc/choose(list/options)
	return options[randrange(length(options)) + 1]

/**
 * Returns one of `options` by whole-number weights, from one random draw. The draw picks a place below the weights'
 * sum, and the option whose share holds that place is taken. The reference returns it in a list of one.
 *
 * Arguments:
 * - options: The list to pick from.
 * - weights: Each option's weight, a whole number, in the same order.
 *
 * Crashes:
 * - Divides by zero when the weights sum to 0.
 */
/datum/dirt_random/proc/choices(list/options, list/weights)
	var/total = 0
	for(var/weight in weights)
		total += weight
	var/target = randrange(total)
	for(var/position in 1 to length(options))
		var/weight = weights[position]
		if(target < weight)
			return options[position]
		target -= weight
	return options[length(options)]

/**
 * Returns a normally distributed number, from two draws (Box-Muller).
 *
 * The first draw is turned round to 1 - random(), so the log never sees 0. DM's trigonometry takes degrees.
 *
 * Arguments:
 * - mean: The centre of the distribution.
 * - deviation: Its standard deviation.
 */
/datum/dirt_random/proc/gauss(mean, deviation)
	var/radius_draw = 1 - random()
	var/angle_draw = random()
	return mean + deviation * sqrt(-2 * log(radius_draw)) * cos(360 * angle_draw)

/**
 * Shuffles `items` in place, from the last position down (Fisher-Yates), with one draw for each position but the first.
 *
 * Arguments:
 * - items: The list to shuffle.
 *
 * Returns:
 * - `items` itself, shuffled.
 */
/datum/dirt_random/proc/shuffle(list/items)
	for(var/position = length(items) - 1, position > 0, position--)
		var/swap = randrange(position + 1)
		items.Swap(position + 1, swap + 1)
	return items

/**
 * Returns a whole number from 0 up to `count`, never `count`, as the reference's draw_index() takes one. That's one
 * randrange() here, and int(random() * count) on the draft stream.
 *
 * Arguments:
 * - count: How many results there are, a positive whole number.
 */
/datum/dirt_random/proc/draw_index(count)
	return randrange(count)

/**
 * Returns `count` of `items` without repeats, as a new list: a Fisher-Yates from the front, stopped after `count`
 * draws. `items` is left as it was.
 *
 * Arguments:
 * - items: The list to pick from.
 * - count: How many to pick, no more than `items` holds.
 *
 * Crashes:
 * - Divides by zero when `count` is more than `items` holds.
 */
/datum/dirt_random/proc/sample(list/items, count)
	var/list/pool = items.Copy()
	for(var/position = 0, position < count, position++)
		var/swap = position + randrange(length(pool) - position)
		pool.Swap(position + 1, swap + 1)
	return pool.Copy(1, count + 1)

/**
 * Returns a general deposit's stream: the draft stream under DIRT_DRAFT_EXACT, else the portable one that mess uses.
 *
 * Arguments:
 * - seed: The stream's text, as the reference spells it ("walk:3").
 */
/proc/dirt_general_stream(seed)
	RETURN_TYPE(/datum/dirt_random)
#ifdef DIRT_DRAFT_EXACT
	return new /datum/dirt_random/draft(seed)
#else
	return new /datum/dirt_random(seed)
#endif

/**
 * The original draft's stream: Python's random.Random(seed text), word for word, so a general deposit draws as the
 * draft drew it. A Mersenne twister (MT19937) seeded from text as CPython seeds it, on 16-bit halves, every product
 * through bytes so nothing passes 2^24. random() is CPython's 53-bit fraction rounded to float32, as the reference
 * rounds it. randrange(), randint(), choose() and shuffle() take whole draws as CPython's _randbelow() does, rejecting
 * those past the count. gauss() keeps the second of each pair for its next call. choices() walks the weights' running
 * sums to the first past random() times their total. That picks what CPython's bisect picks. draw() and sample() are
 * the portable stream's alone, and crash on this one.
 *
 * Every stream of one seed text shares its words (SSdirt.draft_words), so a text is seeded once while it's kept.
 */
/datum/dirt_random/draft
	/// The seed text's words, shared by every stream of it.
	var/datum/dirt_draft_words/words
	/// The next word's place in `words`, from 0.
	var/position = 0
	/// The high half of the word next_word() read last.
	var/word_high = 0
	/// Its low half.
	var/word_low = 0
	/// The second value of gauss()'s last pair, for its next call, or null.
	var/gauss_next

/// Starts a stream at its seed text's first word, sharing the text's words with every other stream of it.
/datum/dirt_random/draft/New(seed)
	. = ..()
	words = SSdirt.draft_words.fetch(src.seed) || SSdirt.draft_words.store_value(src.seed, new /datum/dirt_draft_words(src.seed))

/**
 * Reads the next 32-bit word into word_high and word_low, making it first if no stream of this text has made it yet.
 */
/datum/dirt_random/draft/proc/next_word()
	var/datum/dirt_draft_words/kept = words
	if(position >= kept.count)
		kept.fill(position + 1)
	// three words in four numbers of 24 bits
	var/list/packed = kept.packed
	var/group = floor(position / 3) * 4
	switch(position % 3)
		if(0)
			var/first = packed[group + 1]
			word_high = first >> 8
			word_low = ((first & 255) << 8) | (packed[group + 2] >> 16)
		if(1)
			word_high = packed[group + 2] & 65535
			word_low = packed[group + 3] >> 8
		if(2)
			var/fourth = packed[group + 4]
			word_high = ((packed[group + 3] & 255) << 8) | (fourth >> 16)
			word_low = fourth & 65535
	position++

/**
 * Returns the top `bits` of the next word, as CPython's getrandbits().
 *
 * Arguments:
 * - bits: 1 to 24.
 */
/datum/dirt_random/draft/proc/getrandbits(bits)
	next_word()
	if(bits <= 16)
		return word_high >> (16 - bits)
	return (word_high << (bits - 16)) | (word_low >> (32 - bits))

/**
 * Returns CPython's random(), (first word >> 5) * 2^26 + (second word >> 6) over 2^53, rounded to the nearest
 * float32, ties to even. The rounding keeps the top 24 bits from the first one set, then reads the next bit and whether
 * any bit under it is set. Its two words are read in place, as two next_word() calls would read them.
 */
/datum/dirt_random/draft/random()
	var/datum/dirt_draft_words/kept = words
	if(position + 2 > kept.count)
		kept.fill(position + 2)
	var/list/packed = kept.packed
	var/group = floor(position / 3) * 4
	var/first_high
	var/first_low
	// the first word's place among three in four numbers, the second's after it
	switch(position % 3)
		if(0)
			var/first = packed[group + 1]
			var/second = packed[group + 2]
			first_high = first >> 8
			first_low = ((first & 255) << 8) | (second >> 16)
			word_high = second & 65535
			word_low = packed[group + 3] >> 8
		if(1)
			var/third = packed[group + 3]
			var/fourth = packed[group + 4]
			first_high = packed[group + 2] & 65535
			first_low = third >> 8
			word_high = ((third & 255) << 8) | (fourth >> 16)
			word_low = fourth & 65535
		if(2)
			var/fourth = packed[group + 4]
			var/fifth = packed[group + 5]
			first_high = ((packed[group + 3] & 255) << 8) | (fourth >> 16)
			first_low = fourth & 65535
			word_high = fifth >> 8
			word_low = ((fifth & 255) << 8) | (packed[group + 6] >> 16)
	position += 2
	// the 53 bits: the top 24, then 29 under them as 19 and 10
	var/top = (first_high << 8) | (first_low >> 8)
	var/rest_high = (((first_low >> 5) & 7) << 16) | word_high
	var/rest_low = word_low >> 6
	var/shift = 0
	while(top < 8388608 && shift < 53)
		top = (top << 1) | (rest_high >> 18)
		rest_high = ((rest_high << 1) & 524287) | (rest_low >> 9)
		rest_low = (rest_low << 1) & 1023
		shift++
	if((rest_high & 262144) && ((rest_high & 262143) || rest_low || (top & 1)))
		top++
	return top / (2 ** (24 + shift))

/**
 * Returns a whole number from 0 up to `count`, never `count`, as CPython's _randbelow() does. It takes the top bits of
 * a word, as many as `count` has, and takes them from a new word until they're under `count`.
 *
 * Arguments:
 * - count: A whole number from 1 up to 2^24 - 1.
 */
/datum/dirt_random/draft/randrange(count)
	var/bits = 1
	var/limit = 2
	while(limit <= count && bits < 24)
		bits++
		limit *= 2
	// each draw is under `count` more often than not, so 64 misses in a row don't happen
	for(var/attempt in 1 to 64)
		var/drawn = getrandbits(bits)
		if(drawn < count)
			return drawn
	CRASH("A dirt draft stream drew 64 times past [count].")

/// Returns int(random() * count), taken exactly.
/datum/dirt_random/draft/draw_index(count)
	return dirt_fraction_index(random(), count)

/// Crashes, because it's the portable stream's alone. An md5 random draw here would silently differ from the draft's.
/datum/dirt_random/draft/draw()
	CRASH("A dirt draft stream was asked for a portable stream's draw().")

/// Crashes like draw(), as it's the portable stream's alone.
/datum/dirt_random/draft/sample(list/items, count)
	CRASH("A dirt draft stream was asked for a portable stream's sample().")

/**
 * Returns one of `options` by whole-number weights, as CPython's choices() does. It takes random() times their sum,
 * and returns the first option whose running sum is past it, or the last if none is.
 *
 * Arguments:
 * - options: The list to pick from.
 * - weights: Each option's weight, a whole number, in the same order. Their sum is up to 4096.
 */
/datum/dirt_random/draft/choices(list/options, list/weights)
	var/total = 0
	for(var/weight in weights)
		total += weight
	var/fraction = random()
	var/place = fraction * total
	var/bound = 0
	for(var/option_number in 1 to length(options) - 1)
		bound += weights[option_number]
		// float32 can round the place up onto a bound it's under
		if(bound > place || (bound == place && dirt_fraction_below(fraction, total, bound)))
			return options[option_number]
	return options[length(options)]

/**
 * Returns a normally distributed number as CPython's gauss() does. It makes a pair from two random()s, returns the
 * cosine's and keeps the sine's for the next call.
 *
 * Arguments:
 * - mean: The centre of the distribution.
 * - deviation: Its standard deviation.
 */
/datum/dirt_random/draft/gauss(mean, deviation)
	var/drawn = gauss_next
	gauss_next = null
	if(isnull(drawn))
		var/angle = random() * 360
		var/radius = sqrt(-2 * log(1 - random()))
		drawn = cos(angle) * radius
		gauss_next = sin(angle) * radius
	return mean + drawn * deviation

/**
 * A seed text's draft-stream words, as every stream of it reads them. It holds the tempered words made so far, three
 * packed in four 24-bit numbers. While it's SSdirt.draft_open, it also holds the twister's state to make more. When
 * it's closed and a stream needs more, it's seeded again and twisted on to where it stopped.
 */
/datum/dirt_draft_words
	/// The seed text.
	var/seed
	/// The words made, each word's high then low half, cut in 24-bit pieces: three words in four numbers.
	var/list/packed = list()
	/// How many words are made.
	var/count = 0
	/// The twister's DIRT_DRAFT_WORDS words, high and low halves in turn, or null while it's closed.
	var/list/state

/// Starts an entry for a seed text. Its twister isn't seeded until a stream needs a word.
/datum/dirt_draft_words/New(seed)
	. = ..()
	src.seed = seed

/**
 * Seeds the twister again and twists it on past the words already made, closing the entry that was open.
 */
/datum/dirt_draft_words/proc/open()
	var/datum/dirt_draft_words/was_open = SSdirt.draft_open
	if(was_open && was_open != src)
		was_open.state = null
	SSdirt.draft_open = src
	state = dirt_draft_seeded(seed)
	for(var/made in 0 to count - 1)
		twist(made % DIRT_DRAFT_WORDS)

/**
 * Twists one word of the state in place. Words twist in order, so the next word is still untwisted. The word
 * DIRT_DRAFT_REACH on is already twisted only when the slot is past the first 227, as one whole twist leaves them.
 *
 * Arguments:
 * - slot: The word, 0 to DIRT_DRAFT_WORDS - 1.
 */
/datum/dirt_draft_words/proc/twist(slot)
	var/list/twister = state
	var/following = ((slot + 1) % DIRT_DRAFT_WORDS) * 2
	var/ahead = ((slot + DIRT_DRAFT_REACH) % DIRT_DRAFT_WORDS) * 2
	// the slot's top bit, the next word's other 31
	var/mixed_high = (twister[slot * 2 + 1] & 32768) | (twister[following + 1] & 32767)
	var/mixed_low = twister[following + 2]
	var/high = twister[ahead + 1] ^ (mixed_high >> 1)
	var/low = twister[ahead + 2] ^ ((mixed_low >> 1) | ((mixed_high & 1) << 15))
	if(mixed_low & 1)
		high ^= 39176
		low ^= 45279
	twister[slot * 2 + 1] = high
	twister[slot * 2 + 2] = low

/**
 * Makes words until `wanted` are made, opening the twister first if it's closed.
 *
 * Arguments:
 * - wanted: How many words there should be.
 */
/datum/dirt_draft_words/proc/fill(wanted)
	if(!state)
		open()
	var/list/twister = state
	for(var/made in count to wanted - 1)
		var/slot = made % DIRT_DRAFT_WORDS
		twist(slot)
		// tempered
		var/high = twister[slot * 2 + 1]
		var/low = twister[slot * 2 + 2]
		low ^= (low >> 11) | ((high & 2047) << 5)
		high ^= high >> 11
		var/shifted_high = ((high & 511) << 7) | (low >> 9)
		var/shifted_low = (low & 511) << 7
		high ^= shifted_high & 40236
		low ^= shifted_low & 22144
		high ^= (((high & 1) << 15) | (low >> 1)) & 61382
		low ^= high >> 2
		switch(made % 3)
			if(0)
				packed += (high << 8) | (low >> 8)
				packed += (low & 255) << 16
			if(1)
				packed[length(packed)] |= high
				packed += low << 8
			if(2)
				packed[length(packed)] |= high >> 8
				packed += ((high & 255) << 16) | low
	count = max(count, wanted)

/**
 * Returns the twister's state for a seed text as CPython's random.Random(text) leaves it before its first twist:
 * init_genrand(19650218), then init_by_array() of its key. The key is the text's bytes then their SHA-512 digest, read
 * as one big-endian number and cut into 32-bit words from the lowest. The state is DIRT_DRAFT_WORDS words, high and
 * low halves in turn.
 *
 * Arguments:
 * - seed: The seed text, ASCII.
 */
/proc/dirt_draft_seeded(seed)
	RETURN_TYPE(/list)
	// init_genrand(19650218): the same for every text
	var/static/list/genrand
	if(!genrand)
		var/high = 299
		var/low = 54954
		genrand = list(high, low)
		for(var/slot in 1 to DIRT_DRAFT_WORDS - 1)
			var/mixed_low = low ^ (high >> 14)
			var/product_low = DIRT_DRAFT_PRODUCT_LOW(mixed_low, 35173) + slot
			high = (DIRT_DRAFT_PRODUCT_HIGH(high, mixed_low, 27655, 35173) + (product_low >> 16)) & 65535
			low = product_low & 65535
			genrand += high
			genrand += low
	// the key: the digest's 16 words from its end, then the text's from its end, its short first word zero-padded
	var/digest = rustg_hash_string(RUSTG_HASH_SHA512, seed)
	var/list/key = list()
	for(var/word in 0 to 15)
		var/start = 121 - 8 * word
		key += hex2num(copytext(digest, start, start + 4))
		key += hex2num(copytext(digest, start + 4, start + 8))
	var/text_length = length(seed)
	for(var/word in 0 to ceil(text_length / 4) - 1)
		var/list/bytes = list()
		for(var/byte_position in text_length - 4 * word - 3 to text_length - 4 * word)
			bytes += byte_position >= 1 ? text2ascii(seed, byte_position) : 0
		key += bytes[1] * 256 + bytes[2]
		key += bytes[3] * 256 + bytes[4]
	var/key_words = length(key) / 2
	var/list/state = genrand.Copy()
	var/position = 1
	var/key_position = 0
	for(var/step_number in 1 to max(DIRT_DRAFT_WORDS, key_words))
		var/previous_high = state[position * 2 - 1]
		var/previous_low = state[position * 2] ^ (previous_high >> 14)
		var/mixed_low = state[position * 2 + 2] ^ DIRT_DRAFT_PRODUCT_LOW(previous_low, 26125)
		var/mixed_high = state[position * 2 + 1] ^ DIRT_DRAFT_PRODUCT_HIGH(previous_high, previous_low, 25, 26125)
		mixed_low += key[key_position * 2 + 2] + key_position
		state[position * 2 + 1] = (mixed_high + key[key_position * 2 + 1] + (mixed_low >> 16)) & 65535
		state[position * 2 + 2] = mixed_low & 65535
		position++
		key_position++
		if(position >= DIRT_DRAFT_WORDS)
			state[1] = state[DIRT_DRAFT_WORDS * 2 - 1]
			state[2] = state[DIRT_DRAFT_WORDS * 2]
			position = 1
		if(key_position >= key_words)
			key_position = 0
	for(var/step_number in 1 to DIRT_DRAFT_WORDS - 1)
		var/previous_high = state[position * 2 - 1]
		var/previous_low = state[position * 2] ^ (previous_high >> 14)
		var/mixed_low = (state[position * 2 + 2] ^ DIRT_DRAFT_PRODUCT_LOW(previous_low, 35685)) - position
		var/mixed_high = state[position * 2 + 1] ^ DIRT_DRAFT_PRODUCT_HIGH(previous_high, previous_low, 23896, 35685)
		if(mixed_low < 0)
			mixed_low += 65536
			mixed_high = mixed_high ? mixed_high - 1 : 65535
		state[position * 2 + 1] = mixed_high
		state[position * 2 + 2] = mixed_low
		position++
		if(position >= DIRT_DRAFT_WORDS)
			state[1] = state[DIRT_DRAFT_WORDS * 2 - 1]
			state[2] = state[DIRT_DRAFT_WORDS * 2]
			position = 1
	state[1] = 32768
	state[2] = 0
	return state

/**
 * Returns whether `fraction` * `count` is under `bound`, taken exactly, because float32 can round the product up onto
 * a whole number it's under. The fraction is a mantissa over a power of 2, and mantissa * count is taken in 12-bit
 * pieces.
 *
 * Arguments:
 * - fraction: From 0 to 1, a float32 (random()'s).
 * - count: A whole number from 1 up to 4096.
 * - bound: A whole number.
 */
/proc/dirt_fraction_below(fraction, count, bound)
	if(fraction <= 0)
		return bound > 0
	var/mantissa = fraction * 16777216
	var/shift = 0
	// a float32 over 0 is at least 2^-149
	while(mantissa < 8388608 && shift < 150)
		mantissa *= 2
		shift++
	var/mantissa_high = floor(mantissa / 4096)
	var/product_high = mantissa_high * count + floor((mantissa - mantissa_high * 4096) * count / 4096)
	return product_high < bound * (2 ** (12 + shift))

/**
 * Returns int(fraction * count), taken exactly, as the reference takes the draft's draw_index().
 *
 * Arguments:
 * - fraction: From 0 up to 1, a float32 (random()'s).
 * - count: A whole number from 1 up to 4096.
 */
/proc/dirt_fraction_index(fraction, count)
	var/scaled = fraction * count
	var/index = floor(scaled)
	if(index == scaled && index > 0 && dirt_fraction_below(fraction, count, index))
		return index - 1
	return index

/**
 * Returns the draft's noise hash of a lattice point as its 16 bits, 0 to 65535: (x * 374761393 + y * 668265263 +
 * seed * 2147483647) mod 2^32, then h ^ (h >> 13), times 1274126177, and the low half of h ^ (h >> 16). Every 32-bit
 * word is two 16-bit halves, and a negative number is its two's complement. A point within 512 of the origin reads its
 * column's and row's terms from tables, and a point further out works them out. The last multiply is read a byte at a
 * time from tables (dirt_draft_hash_tables()). Each table entry is the product worked out once, so the bits are the
 * same.
 *
 * Arguments:
 * - cell_x, cell_y: The lattice point, whole numbers of either sign, under 2^24.
 * - seed: The noise field's seed, a whole number of either sign, under 2^24.
 */
/proc/dirt_draft_hash_bits(cell_x, cell_y, seed)
	var/static/list/tables
	tables ||= dirt_draft_hash_tables()
	var/low
	var/high
	if(cell_x >= -512 && cell_x < 512 && cell_y >= -512 && cell_y < 512)
		var/column = (cell_x + 512) * 2
		var/row = (cell_y + 512) * 2 + 2048
		high = tables[column + 1] + tables[row + 1]
		low = tables[column + 2] + tables[row + 2]
	else
		var/x_high = floor(cell_x / 65536)
		var/x_low = cell_x - x_high * 65536
		x_high = DIRT_MODULO(x_high, 65536)
		var/y_high = floor(cell_y / 65536)
		var/y_low = cell_y - y_high * 65536
		y_high = DIRT_MODULO(y_high, 65536)
		low = DIRT_DRAFT_PRODUCT_LOW(x_low, 26545) + DIRT_DRAFT_PRODUCT_LOW(y_low, 60207)
		high = DIRT_DRAFT_PRODUCT_HIGH(x_high, x_low, 5718, 26545) + DIRT_DRAFT_PRODUCT_HIGH(y_high, y_low, 10196, 60207)
	var/seed_high = floor(seed / 65536)
	var/seed_low = seed - seed_high * 65536
	// seed * (2^31 - 1) = seed * 2^31 - seed: the seed is taken off, and its lowest bit put on top
	var/negated_low = DIRT_MODULO(-seed_low, 65536)
	var/negated_high = -seed_high - (seed_low ? 1 : 0)
	negated_high = DIRT_MODULO(negated_high, 65536)
	low += negated_low
	high = (high + negated_high + DIRT_MODULO(seed, 2) * 32768 + (low >> 16)) & 65535
	low &= 65535
	low ^= (low >> 13) | ((high & 8191) << 3)
	high ^= high >> 13
	// times 1274126177: each byte's product, summed mod 2^32
	var/first = (low & 255) * 2 + 4097
	var/second = ((low >> 8) + 256) * 2 + 4097
	var/third = ((high & 255) + 512) * 2 + 4097
	var/fourth = ((high >> 8) + 768) * 2 + 4097
	var/product_low = tables[first + 1] + tables[second + 1] + tables[third + 1] + tables[fourth + 1]
	return ((tables[first] + tables[second] + tables[third] + tables[fourth] + (product_low >> 16)) & 65535) ^ (product_low & 65535)

/**
 * Returns the tables the draft's noise hash reads (dirt_draft_hash_bits()), each 32-bit product as its high half then
 * its low. From 1 are the column terms (x * 374761393) of x from -512 up to 512, at (x + 512) * 2 + 1. From 2049 are
 * the row terms (y * 668265263), laid out the same way. From 4097 is each byte b in byte place t of a word (from the
 * lowest) times 1274126177, at (t * 256 + b) * 2 + 4097. That's 6,144 numbers, about 48 KB, built on the first call.
 * You should NEVER modify it.
 */
/proc/dirt_draft_hash_tables()
	RETURN_TYPE(/list)
	var/static/list/tables
	if(tables)
		return tables
	tables = list()
	for(var/axis in 1 to 2)
		var/by_high = axis == 1 ? 5718 : 10196
		var/by_low = axis == 1 ? 26545 : 60207
		for(var/cell in -512 to 511)
			var/cell_high = floor(cell / 65536)
			var/cell_low = cell - cell_high * 65536
			cell_high = DIRT_MODULO(cell_high, 65536)
			tables += DIRT_DRAFT_PRODUCT_HIGH(cell_high, cell_low, by_high, by_low)
			tables += DIRT_DRAFT_PRODUCT_LOW(cell_low, by_low)
	for(var/place in 0 to 3)
		for(var/byte in 0 to 255)
			var/word_high = place >= 2 ? byte << (8 * (place - 2)) : 0
			var/word_low = place < 2 ? byte << (8 * place) : 0
			tables += DIRT_DRAFT_PRODUCT_HIGH(word_high, word_low, 19441, 40801)
			tables += DIRT_DRAFT_PRODUCT_LOW(word_low, 40801)
	return tables

/**
 * Returns the draft's noise value of a lattice point, from 0 to 1 in steps of 1/65535. SSdirt.lattice keeps it while
 * the general deposit sampling it is drawn (dirt_drafted()).
 *
 * Arguments:
 * - cell_x, cell_y: The lattice point, whole numbers of either sign.
 * - seed: The noise field's seed, a whole number.
 */
/proc/dirt_draft_noise(cell_x, cell_y, seed)
	if(abs(cell_x) >= 2048 || abs(cell_y) >= 2048)
		return dirt_draft_hash_bits(cell_x, cell_y, seed) / 65535
	var/alist/lattice = SSdirt.lattice
	var/alist/points = lattice[seed]
	if(!points)
		points = alist()
		lattice[seed] = points
	var/key = (cell_x + 2048) * 4096 + cell_y + 2048
	. = points[key]
	if(!isnull(.))
		return
	. = dirt_draft_hash_bits(cell_x, cell_y, seed) / 65535
	SSdirt.lattice_points++
	if(SSdirt.lattice_points > DIRT_LATTICE_POINTS)
		lattice.Cut()
		SSdirt.lattice_points = 1
		points = alist()
		lattice[seed] = points
	points[key] = .

/**
 * Returns the table the noise hashes lattice points through: 0 to 255, shuffled by the "dirt:perm" stream.
 *
 * The table is built on the first call and shared after that. You should NEVER modify it.
 */
/proc/dirt_perm_table()
	RETURN_TYPE(/list)
	var/static/list/table
	if(!table)
		var/list/values = list()
		for(var/value in 0 to 255)
			values += value
		var/datum/dirt_random/stream = new("dirt:perm")
		table = stream.shuffle(values)
	return table

/**
 * Returns a lattice point's noise value, from 0 to 1 in steps of 1/255. While a general deposit is drawn under
 * DIRT_DRAFT_EXACT, it's the draft's value (dirt_draft_noise()), read in place where SSdirt.lattice keeps it.
 *
 * The seed's low byte, its next byte and then the point's coordinates are chained through the permutation table.
 * DIRT_MODULO keeps every index in range when a coordinate is negative.
 *
 * Arguments:
 * - cell_x, cell_y: The lattice point, whole numbers of either sign.
 * - seed: The noise field's seed, a whole number.
 */
/proc/dirt_noise_hash(cell_x, cell_y, seed)
#ifdef DIRT_DRAFT_EXACT
	if(SSdirt.drafting)
		// where dirt_draft_noise() keeps it
		if(cell_x > -2048 && cell_x < 2048 && cell_y > -2048 && cell_y < 2048)
			var/alist/points = SSdirt.lattice[seed]
			. = points?[(cell_x + 2048) * 4096 + cell_y + 2048]
			if(!isnull(.))
				return
		return dirt_draft_noise(cell_x, cell_y, seed)
#endif
	var/static/list/table
	table ||= dirt_perm_table()
	var/seed_high = floor(seed / 256)
	var/chained = table[DIRT_MODULO(seed, 256) + 1] + DIRT_MODULO(seed_high, 256)
	chained = table[DIRT_MODULO(chained, 256) + 1] + cell_x
	chained = table[DIRT_MODULO(chained, 256) + 1] + cell_y
	return table[DIRT_MODULO(chained, 256) + 1] / 255

/**
 * Returns smooth value noise from 0 to 1: the four lattice points round a sample, blended with a smoothstep. Each point
 * is dirt_noise_hash()'s, with its chain's seed steps taken once for all four and each column's step once. While a
 * general deposit is drawn under DIRT_DRAFT_EXACT, each point is dirt_draft_noise()'s instead, read in place where
 * SSdirt.lattice keeps all four, and asked of dirt_draft_noise() for the rest.
 *
 * Arguments:
 * - sample_x, sample_y: Where to sample, in pixels.
 * - seed: The noise field's seed, a whole number.
 * - scale: The lattice's spacing, in pixels.
 */
/proc/dirt_value_noise(sample_x, sample_y, seed, scale)
	var/scaled_x = sample_x / scale
	var/scaled_y = sample_y / scale
	var/cell_x = floor(scaled_x)
	var/cell_y = floor(scaled_y)
	var/blend_x = scaled_x - cell_x
	var/blend_y = scaled_y - cell_y
	blend_x = blend_x * blend_x * (3 - 2 * blend_x)
	blend_y = blend_y * blend_y * (3 - 2 * blend_y)
#ifdef DIRT_DRAFT_EXACT
	if(SSdirt.drafting)
		var/draft_top_left
		var/draft_top_right
		var/draft_bottom_left
		var/draft_bottom_right
		// where dirt_draft_noise() keeps them, the next column 4096 keys on and the next row 1 key on
		var/alist/points = SSdirt.lattice[seed]
		if(points && cell_x > -2048 && cell_x < 2047 && cell_y > -2048 && cell_y < 2047)
			var/key = (cell_x + 2048) * 4096 + cell_y + 2048
			draft_top_left = points[key]
			draft_top_right = points[key + 4096]
			draft_bottom_left = points[key + 1]
			draft_bottom_right = points[key + 4097]
		if(isnull(draft_top_left))
			draft_top_left = dirt_draft_noise(cell_x, cell_y, seed)
		if(isnull(draft_top_right))
			draft_top_right = dirt_draft_noise(cell_x + 1, cell_y, seed)
		if(isnull(draft_bottom_left))
			draft_bottom_left = dirt_draft_noise(cell_x, cell_y + 1, seed)
		if(isnull(draft_bottom_right))
			draft_bottom_right = dirt_draft_noise(cell_x + 1, cell_y + 1, seed)
		return (draft_top_left + (draft_top_right - draft_top_left) * blend_x) * (1 - blend_y) + (draft_bottom_left + (draft_bottom_right - draft_bottom_left) * blend_x) * blend_y
#endif
	var/static/list/table
	table ||= dirt_perm_table()
	var/seed_high = floor(seed / 256)
	var/chained = table[DIRT_MODULO(seed, 256) + 1] + DIRT_MODULO(seed_high, 256)
	var/seeded = table[DIRT_MODULO(chained, 256) + 1]
	chained = seeded + cell_x
	var/left = table[DIRT_MODULO(chained, 256) + 1]
	chained = seeded + cell_x + 1
	var/right = table[DIRT_MODULO(chained, 256) + 1]
	chained = left + cell_y
	var/top_left = table[DIRT_MODULO(chained, 256) + 1] / 255
	chained = right + cell_y
	var/top_right = table[DIRT_MODULO(chained, 256) + 1] / 255
	chained = left + cell_y + 1
	var/bottom_left = table[DIRT_MODULO(chained, 256) + 1] / 255
	chained = right + cell_y + 1
	var/bottom_right = table[DIRT_MODULO(chained, 256) + 1] / 255
	return (top_left + (top_right - top_left) * blend_x) * (1 - blend_y) + (bottom_left + (bottom_right - bottom_left) * blend_x) * blend_y

/**
 * Returns two octaves of value noise, stretched back out to cover 0 to 1 (summed noise bunches round 0.5).
 *
 * The second octave is half the scale, on the seed plus 97.
 *
 * Arguments:
 * - sample_x, sample_y: Where to sample, in pixels.
 * - seed: The noise field's seed, a whole number.
 * - scale: The first octave's lattice spacing, in pixels.
 */
/proc/dirt_spread_noise(sample_x, sample_y, seed, scale)
	var/mixed = (dirt_value_noise(sample_x, sample_y, seed, scale) * 2 + dirt_value_noise(sample_x, sample_y, seed + 97, scale / 2)) / 3
	return clamp(0.5 + (mixed - 0.5) * 2.4, 0, 1)

#undef DIRT_DRAFT_WORDS
#undef DIRT_DRAFT_REACH
#undef DIRT_LATTICE_POINTS
#undef DIRT_DRAFT_PRODUCT_LOW
#undef DIRT_DRAFT_PRODUCT_HIGH
