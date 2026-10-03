/// generate_unique_features() lays every feature block down once, in GLOB.dna_feature_blocks order and with nothing between
/// them: the hash is as long as the blocks together, and a block the body sets reads back as that block builds it.
/datum/unit_test/unique_features_hash

/datum/unit_test/unique_features_hash/Run()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.dna.features[FEATURE_MUTANT_COLOR] = "#123456"
	var/hash = body.dna.generate_unique_features()
	var/total = 0
	for(var/block_type, feature_block in GLOB.dna_feature_blocks)
		var/datum/dna_block/feature/block = feature_block
		total += block.block_length
		TEST_ASSERT_EQUAL(length(block.get_block(hash)), block.block_length, "[block_type] must read back a whole block")
	TEST_ASSERT_EQUAL(length(hash), total, "The hash must hold every feature block once and nothing else")
	var/datum/dna_block/feature/mutant_color/color_block = GLOB.dna_feature_blocks[/datum/dna_block/feature/mutant_color]
	TEST_ASSERT_EQUAL(color_block.get_block(hash), "123456", "The mutant colour block must read back as the body's colour")
