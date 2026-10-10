import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


CHECKER = Path(__file__).with_name('ticked_file_enforcement.py')


def include(name):
    return f'#include "code\\{name}.dm"'


class ConditionalIncludeTests(unittest.TestCase):
    def check(self, lines, files=('a', 'b'), forbidden=()):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'code').mkdir()
            for name in files:
                (root / 'code' / f'{name}.dm').write_text('// fixture\n')
            (root / 'project.dme').write_text('\n'.join([
                '// header', '// BEGIN_INCLUDE', *lines, '// END_INCLUDE',
            ]) + '\n')
            schema = {
                'file': 'project.dme', 'scannable_directory': 'code/',
                'subdirectories': True, 'excluded_files': [],
                'forbidden_includes': list(forbidden),
            }
            return subprocess.run(
                [sys.executable, '-B', str(CHECKER)], cwd=root,
                input=json.dumps(schema), capture_output=True, text=True, timeout=10,
            )

    def test_unconditional_list_keeps_existing_checks(self):
        result = self.check([include('a'), include('b')])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('1 configurations', result.stdout)

    def test_mutually_exclusive_shared_include_is_not_a_duplicate(self):
        result = self.check([
            include('a'), '#ifdef DOGMOS_IN_PROCESS', include('b'),
            '#else', include('b'), '#endif', include('c'),
        ], files=('a', 'b', 'c'))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('2 configurations', result.stdout)

    def test_repeated_define_uses_the_same_assignment(self):
        result = self.check([
            '#ifdef BACKEND', include('a'), '#else', include('b'), '#endif',
            '#ifndef BACKEND', include('c'), '#else', include('b'), '#endif',
        ], files=('a', 'b', 'c'))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_nested_conditionals_and_implicit_empty_branch(self):
        result = self.check([
            include('a'), '#ifdef BACKEND', '#ifndef FEATURE', include('b'),
            '#else', include('c'), '#endif', '#endif', include('d'),
        ], files=('a', 'b', 'c', 'd'))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('4 configurations', result.stdout)

    def test_duplicate_in_one_active_configuration_is_rejected(self):
        result = self.check([
            include('a'), '#ifdef BACKEND', include('a'),
            '#else', include('b'), '#endif',
        ])
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('Two lines were exactly the same', result.stdout)

    def test_ordering_is_checked_inside_and_across_branches(self):
        for lines in (
            ['#ifdef BACKEND', include('b'), include('a'), '#else', include('a'), include('b'), '#endif'],
            ['#ifdef BACKEND', include('b'), '#endif', include('a')],
        ):
            with self.subTest(lines=lines):
                result = self.check(lines)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn('out of order', result.stdout)
                self.assertIn("'BACKEND': True", result.stdout)

    def test_missing_include_is_still_rejected(self):
        result = self.check(['#ifdef BACKEND', include('a'), '#endif'])
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('Missing include for code\\b.dm', result.stdout)

    def test_forbidden_include_is_rejected_in_either_branch(self):
        result = self.check([
            '#ifdef BACKEND', include('a'), '#else', include('b'), '#endif',
        ], forbidden=('code/b.dm',))
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('code\\b.dm should NOT be included', result.stdout)

    def test_malformed_or_unsupported_directives_fail_closed(self):
        for directives in (
            ['#else'], ['#endif'], ['#ifdef BACKEND'],
            ['#ifdef BACKEND', '#else', '#else', '#endif'],
            ['#if SOME_EXPRESSION', '#endif'], ['#define BACKEND 1'],
        ):
            with self.subTest(directives=directives):
                result = self.check([include('a'), *directives, include('b')])
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn('line ', result.stdout)


if __name__ == '__main__':
    unittest.main()
