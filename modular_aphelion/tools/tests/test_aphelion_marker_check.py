import unittest

from modular_aphelion.tools.aphelion_marker_check import validate_diff


def diff(*lines: str, path: str = "code/example.dm", new_file: bool = False) -> str:
	header = ["--- /dev/null" if new_file else f"--- a/{path}", f"+++ b/{path}"]
	return "\n".join([*header, "@@ -1,0 +1,%d @@" % len(lines), *(f"+{line}" for line in lines)])


class MarkerCheckTests(unittest.TestCase):
	def test_accepts_canonical_aphelion_markers(self) -> None:
		self.assertEqual(validate_diff(diff(
			"// APHELION EDIT ADDITION START - DOGMOS",
			"new_behavior()",
			"// APHELION EDIT ADDITION END",
		)), [])

	def test_rejects_unmarked_existing_core_edit(self) -> None:
		errors = validate_diff(diff("changed_behavior()"))
		self.assertIn("unmarked_core_edit", {error.code for error in errors})

	def test_accepts_narrow_dogmos_atmosphere_exception(self) -> None:
		for path in (
			"code/modules/atmospherics/gasmixtures/gas_mixture.dm",
			"code/modules/atmospherics/environmental/LINDA_system.dm",
			"code/__DEFINES/dogmos_bindings.dm",
			"code/__DEFINES/dogmos_contract.dm",
		):
			with self.subTest(path=path):
				self.assertEqual(validate_diff(diff("changed_behavior()", path=path)), [])

	def test_exception_does_not_cover_unrelated_atmos_machinery(self) -> None:
		errors = validate_diff(diff("changed_behavior()", path="code/modules/atmospherics/machinery/atmosmachinery.dm"))
		self.assertIn("unmarked_core_edit", {error.code for error in errors})

	def test_accepts_new_aphelion_owned_file_without_inline_markers(self) -> None:
		self.assertEqual(validate_diff(diff("/datum/unit_test/dogmos_example", new_file=True)), [])

	def test_rejects_new_nova_marker_outside_nova(self) -> None:
		errors = validate_diff(diff("// NOVA EDIT ADDITION START - NEW_FEATURE"))
		self.assertIn("new_nova_marker", {error.code for error in errors})

	def test_reports_invalid_or_unclosed_aphelion_markers(self) -> None:
		errors = validate_diff(diff("// APHELION EDIT ADDITION START - bad-id"))
		self.assertEqual({error.code for error in errors}, {"invalid_module_id", "unclosed_marker"})


if __name__ == "__main__":
	unittest.main()
