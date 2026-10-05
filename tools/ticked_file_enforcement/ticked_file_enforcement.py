import codecs
import fnmatch
import functools
import glob
import itertools
import json
import os
import re
import sys

# simple way to check if we're running on github actions, or on a local machine
on_github = os.getenv("GITHUB_ACTIONS") == "true"

def green(text):
    return "\033[32m" + str(text) + "\033[0m"

def red(text):
    return "\033[31m" + str(text) + "\033[0m"

def blue(text):
    return "\033[34m" + str(text) + "\033[0m"

def read_include_records(path):
    """Read the managed block without merging mutually exclusive backend includes."""
    records = []
    defines = set()
    reading = False
    branches = []
    # NOVA spellings kept so upstream ports don't break.
    marker = re.compile(r"// (?:APHELION|NOVA) EDIT ADDITION (?:START(?: - [A-Z][A-Z0-9_]*)?|END)")
    with open(path) as source:
        for number, raw in enumerate(source, 1):
            line = raw.strip()
            if line == "// BEGIN_INCLUDE":
                reading = True
                continue
            if not reading:
                continue
            if line == "// END_INCLUDE":
                if branches:
                    raise ValueError(f"line {number}: unclosed conditional include block")
                return records, sorted(defines), number - len(records)
            if marker.fullmatch(line):
                continue
            if re.fullmatch(r'#include "[^"]+"', line):
                records.append((number, "include", line))
                continue
            directive = line.partition("//")[0].strip()
            condition = re.fullmatch(r'#(ifdef|ifndef)\s+([A-Za-z_]\w*)', directive)
            if condition:
                kind, name = condition.groups()
                defines.add(name)
                branches.append(False)
                records.append((number, kind, name))
            elif directive == "#else":
                if not branches or branches[-1]:
                    raise ValueError(f"line {number}: unmatched or repeated #else")
                branches[-1] = True
                records.append((number, "else", None))
            elif directive == "#endif":
                if not branches:
                    raise ValueError(f"line {number}: unmatched #endif")
                branches.pop()
                records.append((number, "endif", None))
            else:
                raise ValueError(f"line {number}: unsupported include-block line: {line}")
    raise ValueError("missing managed include block or // END_INCLUDE")


def include_configurations(records, defines):
    """Check every define assignment, including correlated and nested conditionals."""
    for assignment in itertools.product((False, True), repeat=len(defines)):
        values = dict(zip(defines, assignment))
        active = [True]
        includes = []
        for number, kind, value in records:
            if kind == "include":
                if active[-1]:
                    includes.append((number, value))
            elif kind in ("ifdef", "ifndef"):
                enabled = values[value] if kind == "ifdef" else not values[value]
                active.append(active[-1] and enabled)
            elif kind == "else":
                active[-1] = active[-2] and not active[-1]
            else:
                active.pop()
        yield values, includes

schema = json.load(sys.stdin)
file_reference = schema["file"]
file_reference_basename = os.path.basename(file_reference)
scannable_directory = schema["scannable_directory"]
subdirectories = schema["subdirectories"]
FORBIDDEN_INCLUDES = schema["forbidden_includes"]
excluded_files = schema["excluded_files"]

def post_error(string):
    print(red(f"Ticked File Enforcement [{file_reference}]: " + string))
    if on_github:
        print(f"::error file={file_reference},line=1,title=Ticked File Enforcement::{string}")

for excluded_file in excluded_files:
    full_file_path = scannable_directory + excluded_file
    if not os.path.isfile(full_file_path):
        post_error(f"Excluded file {full_file_path} does not exist, please remove it!")
        sys.exit(1)

file_extensions = ("dm", "dmf")

# Keep coverage checks across all branches; ordering checks run per configuration below.
try:
    records, defines, offset = read_include_records(file_reference)
except ValueError as error:
    post_error(str(error))
    sys.exit(1)
lines = [line for _, kind, line in records if kind == "include"]
print(blue(f"Ticked File Enforcement: {offset} lines were ignored in output for [{file_reference}]."))
fail_no_include = False

scannable_files = []
for file_extension in file_extensions:
    compiled_directory = f"{scannable_directory}/**/*.{file_extension}"
    scannable_files += glob.glob(compiled_directory, recursive=True)

if len(scannable_files) == 0:
    post_error(f"No files were found in {scannable_directory}. Ticked File Enforcement has failed!")
    sys.exit(1)

for code_file in scannable_files:
    dm_path = ""

    if subdirectories is True:
        dm_path = code_file.replace('/', '\\')
    else:
        # APHELION EDIT REMOVAL START - Modular unit tests in nested folders
        # dm_path = os.path.basename(code_file)
        # # NOVA EDIT START - Modular unit tests - have to append this again after it gets removed; this was not designed upstream with subfolders for unit tests in mind so we must cope.
        # if("~nova/" in code_file):
        #     dm_path = "~nova\\" + dm_path
        # # NOVA EDIT END
        # APHELION EDIT REMOVAL END
        # APHELION EDIT ADDITION START - Modular unit tests in nested folders
        # Keep the path under the scannable directory (not just the basename) so nested folders such
        # as ~nova/custom_sprites/ match their #include lines; upstream assumes a flat directory.
        # Flat files are unaffected (relpath == basename).
        dm_path = os.path.relpath(code_file, scannable_directory).replace(os.sep, '\\')
        # APHELION EDIT ADDITION END

    included = f"#include \"{dm_path}\"" in lines

    forbid_include = False
    for forbidable in FORBIDDEN_INCLUDES:
        if not fnmatch.fnmatch(code_file, forbidable):
            continue

        forbid_include = True

        if included:
            post_error(f"{dm_path} should NOT be included.")
            fail_no_include = True

    if forbid_include:
        continue

    if not included:
        if(dm_path == file_reference_basename):
            continue

        if(dm_path in excluded_files):
            continue

        post_error(f"Missing include for {dm_path}.")
        fail_no_include = True

if fail_no_include:
    sys.exit(1)

def compare_lines(a, b):
    # Remove initial include as well as the final quotation mark
    a = a[len("#include \""):-1].lower()
    b = b[len("#include \""):-1].lower()

    split_by_period = a.split('.')
    a_suffix = ""
    if len(split_by_period) >= 2:
        a_suffix = split_by_period[len(split_by_period) - 1]
    split_by_period = b.split('.')
    b_suffix = ""
    if len(split_by_period) >= 2:
        b_suffix = split_by_period[len(split_by_period) - 1]

    a_segments = a.split('\\')
    b_segments = b.split('\\')

    for (a_segment, b_segment) in zip(a_segments, b_segments):
        a_is_file = a_segment.endswith(file_extensions)
        b_is_file = b_segment.endswith(file_extensions)

        # code\something.dm will ALWAYS come before code\directory\something.dm
        if a_is_file and not b_is_file:
            return -1

        if b_is_file and not a_is_file:
            return 1

        # interface\something.dm will ALWAYS come after code\something.dm
        if a_segment != b_segment:
            # if we're at the end of a compare, then this is about the file name
            # files with longer suffixes come after ones with shorter ones
            if a_suffix != b_suffix:
                return (a_suffix > b_suffix) - (a_suffix < b_suffix)
            return (a_segment > b_segment) - (a_segment < b_segment)

    print(f"Two lines were exactly the same ({a} vs. {b})")
    sys.exit(1)

configuration_count = 0
for values, includes in include_configurations(records, defines):
    configuration_count += 1
    active_lines = [line for _, line in includes]
    sorted_lines = sorted(active_lines, key=functools.cmp_to_key(compare_lines))
    for (index, (number, line)) in enumerate(includes):
        if sorted_lines[index] != line:
            post_error(f"The include at line {number} is out of order ({line}, expected {sorted_lines[index]}; defines={values})")
            sys.exit(1)

print(green(f"Ticked File Enforcement: [{file_reference}] All includes (for {len(scannable_files)} scanned files, {configuration_count} configurations) are in order!"))
