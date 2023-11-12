import argparse
import csv
import json

style = "font-size:12pt;font-weight:400;"
HIGHLIGHT_WORDS=["affirmative action", "affirmative-action", "Affirmative action", "Affirmative-action"]

def process_paragraph(text, highlight_words=HIGHLIGHT_WORDS):
    for word in highlight_words:
        text = text.replace(word, f"<span style=\"background-color:yellow;\">{word}</span>")
    result = f"<p style='{style}'>{text}</p>"
    print(result)
    return result


def prep_potato(text, title):
    paragraphs = text.split('\n')
    wrapped_paragraphs = [process_paragraph(p) for p in paragraphs if p.strip()]
    text = ''.join(wrapped_paragraphs)
    return f"<div><p>{title}</p>{text}</div>"

def process_row(row, filename_column='textfile', title_column='title'):
    filename = row.get(filename_column)
    title = row.get(title_column)
    if filename:
        try:
            with open(filename, 'r', encoding='utf-8') as text_file:
                content = text_file.read()
                text = prep_potato(content, title)
                return {
                    "id": filename,
                    "text": text
                }
        except FileNotFoundError:
            print(f'File not found: {filename}')
        except Exception as e:
            print(f'Error reading file {filename}: {e}')


def process_tsv(tsv_file, filename_column='textfile'):
    records = []
    with open(tsv_file, 'rt') as file:
        reader = csv.DictReader(file, delimiter='\t')
        for row in reader:
            potato_record = process_row(row)
            records.append(potato_record)
    return records

def main():
    parser = argparse.ArgumentParser(description='Convert tsv to JSON for potato')
    parser.add_argument('tsv_file', help='TSV file containing a column with filenames')
    parser.add_argument('json_file', help='Destination JSON file')
    args = parser.parse_args()
    records = process_tsv(args.tsv_file)
    with open(args.json_file, 'wt') as of: 
        for r in records:
            of.write(json.dumps(r))
            of.write('\n')


if __name__ == "__main__":
    main()
