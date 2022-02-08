import argparse
import os


def parameterise_hygiene_test(parameter_pattern: str, parameter_value: str, input_folder: str, output_folder: str):
    for root, subfolder_paths, file_names in os.walk(input_folder):
        for file_name in file_names:
            if 'sparql' in file_name:
                input_file_path = os.path.join(input_folder, file_name)
                input_file = open(input_file_path, 'r')
                input_file_content = input_file.read()
                output_file_content = input_file_content.replace(parameter_pattern, '"' + parameter_value + '"')
                input_file.close()
                output_file_path = os.path.join(output_folder, file_name)
                output_file = open(output_file_path, 'w')
                output_file.write(output_file_content)
                output_file.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Parameterize all hygiene tests')
    parser.add_argument('--input_folder', help='Path to input folder', metavar='IN')
    parser.add_argument('--pattern', help='Pattern parameter', metavar='PATTERN')
    parser.add_argument('--value', help='Pattern value', metavar='VALUE')
    parser.add_argument('--output_folder', help='Path to output folder', metavar='OUT')
    args = parser.parse_args()
    
    parameterise_hygiene_test(
        parameter_pattern=args.pattern,
        parameter_value=args.value,
        input_folder=args.input_folder,
        output_folder=args.output_folder)
    