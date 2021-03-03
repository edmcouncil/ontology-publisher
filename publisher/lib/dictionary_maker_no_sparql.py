import argparse

import numpy
import pandas


def extend_data_dictionary(data_dictionary_file_path: str, extended_data_dictionary: str):
    dictionary = pandas.read_csv(filepath_or_buffer=data_dictionary_file_path)

    extended_dictionary = dictionary.copy()
    extended_dictionary.drop_duplicates(inplace=True)
    extended_dictionary.fillna(value='', inplace=True)

    extended_dictionary['restrictingClassLabel'] = extended_dictionary['restrictingClassLabel'].str.strip()
    extended_dictionary['union'] = extended_dictionary['union'].astype(str)
    extended_dictionary['intersection'] = extended_dictionary['intersection'].astype(str)
    extended_dictionary['restrictingUnionClassLabel'] = \
        extended_dictionary.groupby(by=['Term', 'Synonym', 'Example', 'Explanation']).union.transform(lambda x: ' or '.join(filter(None, x)))
    extended_dictionary['restrictingIntersectionClassLabel'] = \
        extended_dictionary.groupby(by=['Term', 'Synonym', 'Example', 'Explanation']).intersection.transform(lambda x: ' and '.join(filter(None, x)))
    extended_dictionary.drop_duplicates(inplace=True)
    extended_dictionary['restrictingClassLabel'] = \
        numpy.where(
            extended_dictionary['restrictingClassLabel'].str.len() > 0,
            extended_dictionary['restrictingClassLabel'],
            extended_dictionary['restrictingUnionClassLabel'])
    extended_dictionary['restrictingClassLabel'] = \
        numpy.where(
            extended_dictionary['restrictingClassLabel'].str.len() > 0,
            extended_dictionary['restrictingClassLabel'],
            extended_dictionary['restrictingIntersectionClassLabel'])
    extended_dictionary.drop_duplicates(inplace=True)
    extended_dictionary['restriction'] = \
        extended_dictionary['restrictingPropertyLabel'] + \
        ' ' + \
        extended_dictionary['cardinality'] + \
        ' ' + \
        extended_dictionary['restrictingClassLabel']
    extended_dictionary['restriction'] = extended_dictionary['restriction'].str.strip()
    extended_dictionary.drop_duplicates(inplace=True)
    extended_dictionary['restriction_definition'] = \
        extended_dictionary.groupby(by=['Term', 'Synonym', 'Example', 'Explanation']).restriction.transform(lambda x: ', '.join(filter(None, x)))
    extended_dictionary.drop_duplicates(inplace=True)
    extended_dictionary['non_restriction_definition'] = \
        extended_dictionary.groupby(by=['Term', 'Synonym', 'Example', 'Explanation']).superClassLabel.transform(lambda x: ', '.join(filter(None, x)))
    extended_dictionary['non_restriction_definition'] = extended_dictionary['non_restriction_definition'].astype(str)
    extended_dictionary.drop_duplicates(inplace=True)
    extended_dictionary['restriction_definition'] = extended_dictionary['restriction_definition'].astype(str)
    extended_dictionary.drop_duplicates(inplace=True)

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
        columns=['superClassLabel',
                 'union',
                 'intersection',
                 'restriction',
                 'non_restriction_definition',
                 'restriction_definition',
                 'restrictingPropertyLabel',
                 'restrictingUnionClassLabel',
                 'restrictingIntersectionClassLabel',
                 'restrictingClassLabel',
                 'cardinality'],
        inplace=True)
    extended_dictionary.drop_duplicates(inplace=True)

    extended_dictionary['Synonyms'] = \
        extended_dictionary.groupby(by=['Term', 'Example', 'Explanation']).Synonym.transform(lambda x: ', '.join(filter(None, x)))
    extended_dictionary.drop(columns=['Synonym'], inplace=True)
    extended_dictionary.drop_duplicates(inplace=True)

    extended_dictionary['Examples'] = \
        extended_dictionary.groupby(by=['Term', 'Explanation']).Example.transform(lambda x: ', '.join(filter(None, x)))
    extended_dictionary.drop(columns=['Example'], inplace=True)
    extended_dictionary.drop_duplicates(inplace=True)

    extended_dictionary['Explanations'] = \
        extended_dictionary.groupby(by=['Term']).Explanation.transform(lambda x: '. '.join(filter(None, x)))
    extended_dictionary.drop(columns=['Explanation'], inplace=True)
    extended_dictionary.drop_duplicates(inplace=True)

    extended_dictionary.sort_values(by=['Term'], inplace=True)
    extended_dictionary = \
        extended_dictionary[
            ['Term',
             'Type',
             'Ontology',
             'Synonyms',
             'Definition',
             'GeneratedDefinition',
             'Examples',
             'Explanations',
             'Maturity']]
    extended_dictionary.drop_duplicates(inplace=True)

    extended_dictionary.to_csv(extended_data_dictionary, index=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generates textual definitions from logical constraints')
    parser.add_argument('--input', help='Path to input csv file', metavar='IN')
    parser.add_argument('--output', help='Path to output csv file', metavar='OUT')
    args = parser.parse_args()

    extend_data_dictionary(data_dictionary_file_path=args.input, extended_data_dictionary=args.output)
