"""
        parse_hygiene_log

        @author Sam Stouffer

        Parse an ontology hygiene output log into a JUnit XML test report.

"""

import re
import argparse

from pathlib import Path
from junit_xml import TestSuite, TestCase

def parse_hygiene_log(log_path: Path, include_warnings: bool) -> TestSuite:
    test_regex = re.compile("^TEST: (?P<test_name>.*)$")
    error_regex = re.compile("^\"?(?P<error_type>error|warn):", re.IGNORECASE)
    test_cases = []
    current_test_case = None
    current_error_msg = None

    with open(log_path) as log_file:
        for line in log_file.readlines():
            test_match = test_regex.match(line)
            error_match = error_regex.match(line)

            if (test_match or error_match) and current_test_case and current_error_msg:
                # If there is a new case or error detected, close out an existing error message
                if current_test_case and current_error_msg:
                    current_test_case.add_error_info(message=current_error_msg.strip())
                current_error_msg = None
            if test_match:
                if current_test_case:
                    test_cases.append(current_test_case)
                name = test_match.group("test_name")
                current_test_case = TestCase(name=name, allow_multiple_subelements=True)
            elif error_match:
                # Start a new error message only if it is an error or warnings are included as errors.
                if include_warnings or error_match.group('error_type').lower() == 'error':
                    current_error_msg = line
            elif current_error_msg:
                current_error_msg += line
        return TestSuite(name="ontology_hygiene_tests", test_cases=test_cases)


if __name__ == "__main__":
        parser = argparse.ArgumentParser(description="Parse an ontology hygiene output log into a JUnit XML test report.")
        parser.add_argument("path", help="path to log file to parse")
        parser.add_argument("destination", nargs="?", help="destination path where JUnit XML will be written.  Will write to stdout if omitted.")
        parser.add_argument("--include-warnings", default=False, action='store_true', help="Count warnings as errors")
        args = parser.parse_args()

        log_path = Path(args.path)

        suite = parse_hygiene_log(log_path=log_path, include_warnings=args.include_warnings)

        if args.destination:
            dest_path = Path(args.destination)
            with open(dest_path, "w") as dest_file:
                TestSuite.to_file(dest_file, [suite])
        else:
            print(TestSuite.to_xml_string([suite]))
