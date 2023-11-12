"""
script to take the raw xml from the proquest database and turn it into a tsv dataframe and
directory of raw text files
"""

RAW_DIR = "affirmative_action_opeds_raw/pt1/"
TEXT_DIR = "aa_opeds_full/txt/"
OUTFILE = "aa_opeds_full/opeds.tsv"
import os
import csv
import bs4
import random

records = []
for file in os.listdir(RAW_DIR):
    soup = bs4.BeautifulSoup(open(RAW_DIR + file), features="xml")
    text_node = soup.find("Text")
    source = soup.find("PubFrosting").find("Title").text.strip()
    title = soup.find("TitleAtt").find("Title").text.strip()
    date = soup.find("NumericDate").text
    author_node = soup.find("Author")
    author_raw = None
    author_normalized = None
    if (author_node):
        normalized = author_node.find('NormalizedDisplayForm')
        display = author_node.find('DisplayForm')
        if (normalized):
            author_normalized = normalized.text.strip()
        elif display:
            author_raw = display.text.strip()
        else:
            import pdb
            pdb.set_trace()
            author_raw = author_node.text.strip()
    textfile = TEXT_DIR + file + ".txt"
    if (text_node is not None):
        text_raw = text_node.text
        text_soup = bs4.BeautifulSoup(text_raw, features="xml")
        paras = text_soup.findAll("p")
        for para in paras:
            pt = para.text.lower()
            if 'affirmative' in pt and 'action' in pt:
                with open(textfile, "w") as of:
                    #of.writelines((p.text.strip() + "\n" for p in paras))
                    pass
                records.append(
                    {
                        "date": date, 
                        "source": source, 
                        "title": title, 
                        "filename": textfile, 
                        "missingText": text_node is None, 
                        "author_normalized": author_normalized, 
                        "byline": author_raw
                    }
                )
                break

with open(OUTFILE, "w") as of:
    writer = csv.DictWriter(
        of, 
        fieldnames=[
            "date", 
            "source", 
            "title", 
            "author_normalized", 
            "byline", 
            "filename", 
            "missingText"
        ], delimiter="\t"
    )
    writer.writeheader()
    writer.writerows(records)
