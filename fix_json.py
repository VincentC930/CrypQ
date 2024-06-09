# replace "file_path" with actual file path
# replace "year" with the actual slice you intend to use
files = ['/file_path/adjusted_contracts_year_blocks.json',
         '/file_path/adjusted_tokens_year_blocks.json',
         '/file_path/adjusted_balance_year_blocks.json']

for file in files:
    with open(file, 'r') as curr:
        lines = curr.readlines()
        filtered_lines = ''.join(lines[2:-2])

    with open(file.split('.json')[0] + '_filtered.json', 'w') as curr:
        curr.write(filtered_lines)