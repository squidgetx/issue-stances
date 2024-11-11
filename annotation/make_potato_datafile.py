# Make a potato json datafile given input CSV with paths to txt

import csv
import json

def process_csv_to_json(csv_file, output_json):
    with open(output_json, 'w') as json_lines_file:
        with open(csv_file, 'r') as csvfile:
            reader = csv.DictReader(csvfile, delimiter='\t')
            for row in reader:
                filename = "../opeds_nafta/" + row['textfile']
                title = row['title']
                identifier = row['filename']
                html_text = read_file_to_html(filename)
                html_text = f"<h2>{title}</h2>" + html_text
                json_line = {
                    'id': identifier,
                    'text': html_text
                }
                json_lines_file.write(json.dumps(json_line) + '\n')

def read_file_to_html(filename):
    html_text = ''
    with open(filename, 'r') as file:
        for line in file:
            text = line.strip()
            text = text.replace('NAFTA', '<span style="background-color: yellow">NAFTA</span>')
            text = text.replace('Nafta', '<span style="background-color: yellow">NAFTA</span>')
            text = text.replace('nafta', '<span style="background-color: yellow">NAFTA</span>')
            text = text.replace('trade', '<span style="background-color: yellow">trade</span>')
            text = text.replace('Trade', '<span style="background-color: yellow">Trade</span>')
            html_text += f"<p style='font-size:12pt;font-weight:400;'>{text}</p>\n"
    return html_text

# Example usage
input_csv_file = '../opeds_nafta/annotation_sample.tsv'
output_json_file = 'nafta_potato/data_files/nafta_sample.json'
process_csv_to_json(input_csv_file, output_json_file)
