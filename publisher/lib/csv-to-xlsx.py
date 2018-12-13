#!/opt/python3/bin/python3
import sys
import csv
import xlsxwriter

# Copyright (c) Adaptive, Inc 2018
# Author Pete Rivett
# Licensed under MIT License

# Converts a CSV file to formatted ExcelWorkbook
# Assumes input has following columns:
# Table, Definition, Field, Field Definition, Type, Module

# Makes use of xlsxwriter
# - install using pip install xlsxwriter
# - documentation at http://xlsxwriter.readthedocs.io
# - source at https://github.com/jmcnamara/XlsxWriter

# CLI takes name of input CSV file and output an Excel file which will be overwritten
if len(sys.argv) != 4:
    print("Provide name of input CSV file and output Excel file which will be overwritten")
    sys.exit()

inputfile = sys.argv[1]
outputfile = sys.argv[2]
configfile = sys.argv[3]

workbook = xlsxwriter.Workbook(outputfile)
worksheet = workbook.add_worksheet()

# Define formats referenced later
header = workbook.add_format({'bold': True, 'align': 'center', 'bg_color': '#DAA520'})
header.set_border()
evenline = workbook.add_format({'valign':'top', 'bg_color': '#CCFFFF'})
evenline.set_border()
evenline.set_text_wrap()
oddline = workbook.add_format({'valign':'top', 'bg_color': '#FFFFFF'})
oddline.set_border()
oddline.set_text_wrap()

with open(inputfile, 'rt', encoding='utf8') as f:
    reader = csv.reader(f)
    for r, row in enumerate(reader):
        for c, col in enumerate(row):
            if r == 0:
                worksheet.write(r, c, col, header)
            elif r % 2 == 0:
                worksheet.write(r, c, col, evenline)
            else:
                worksheet.write(r, c, col, oddline)

# Formatting

with open (configfile, 'rt',  encoding='utf8') as g:
    reader=csv.reader(g)
    for r, row in enumerate(reader):
        print (row)
        worksheet.set_column (int(row[0]),int(row[1]),int(row[2]))



worksheet.freeze_panes(1, 0)
workbook.close()
