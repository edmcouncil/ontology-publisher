import argparse

import numpy
import pandas


def extend_data_dictionary(data_dictionary_file_path: str, extended_data_dictionary: str):
    dictionary = pandas.read_csv(filepath_or_buffer=data_dictionary_file_path)

    extended_dictionary = dictionary.copy()
    extended_dictionary.drop_duplicates(inplace=True)
    extended_dictionary.fillna(value='', inplace=True)
    extended_dictionary['Synonym'] = extended_dictionary.groupby(by='Term').synonym.transform(
        lambda x: ', '.join(filter(None, x)))
    extended_dictionary.drop(columns=['synonym'], inplace=True)
    extended_dictionary.drop_duplicates(inplace=True)
    extended_dictionary['restriction'] = extended_dictionary['restrictingPropertyLabel'] + ' ' + extended_dictionary[
        'cardinality'] + ' ' + extended_dictionary['restrictingClassLabel']
    extended_dictionary['restriction'] = extended_dictionary['restriction'].str.strip()
    extended_dictionary['non_restriction_definition'] = extended_dictionary.groupby(
        by='Term').superClassLabel.transform(lambda x: ', '.join(filter(None, x)))
    extended_dictionary['restriction_definition'] = extended_dictionary.groupby(by='Term').restriction.transform(
        lambda x: ', '.join(filter(None, x)))
    extended_dictionary['GeneratedDefinition'] = \
        numpy.where(
            extended_dictionary['non_restriction_definition'].str.len() > 0,
            'It is a kind of ' + extended_dictionary['non_restriction_definition'] + '. ',
            '')

    extended_dictionary['GeneratedDefinition'] = \
        numpy.where(
            extended_dictionary['restriction_definition'].str.len() > 0,
            extended_dictionary['GeneratedDefinition'] + 'It ' + extended_dictionary['restriction_definition'] + '.',
            extended_dictionary['GeneratedDefinition'])

    extended_dictionary.drop(
        columns=['superClassLabel', 'restriction', 'non_restriction_definition', 'restriction_definition',
                 'restrictingPropertyLabel', 'restrictingClassLabel', 'cardinality'],
        inplace=True)
    extended_dictionary.drop_duplicates(inplace=True)
    extended_dictionary.sort_values(by=['Term'], inplace=True)
    extended_dictionary = \
        extended_dictionary[
            ['Term', 'Type', 'Synonym', 'Definition', 'GeneratedDefinition', 'Example', 'Explanation', 'Ontology',
             'Maturity']]
    extended_dictionary.to_csv(extended_data_dictionary, index=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generates textual definitions from logical constraints')
    parser.add_argument('--input', help='Path to input csv file', metavar='IN')
    parser.add_argument('--output', help='Path to output csv file', metavar='OUO')
    args = parser.parse_args()

    extend_data_dictionary(data_dictionary_file_path=args.input, extended_data_dictionary=args.output)
