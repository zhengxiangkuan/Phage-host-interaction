import pandas as pd

def parse_biosample_result(file_path, output_csv_path):
    rows = []
    current_row = {}
    in_attributes = False
    identifier_found = False

    with open(file_path, 'r') as file:
        for line in file:
            line = line.strip()

            # 检查是否是标识符行
            if line.startswith('Identifiers:'):
                # 解析标识符行
                identifiers = line.split(';')
                for identifier in identifiers:
                    if 'BioSample:' in identifier:
                        current_row['BioSample'] = identifier.split(':')[1].strip()
                    elif 'SRA:' in identifier:
                        current_row['SRA'] = identifier.split(':')[1].strip()
                # 标识符已找到，开始解析属性
                identifier_found = True
                in_attributes = True

            # 检查是否是属性行
            elif in_attributes and line.startswith('/'):
                # 解析属性行
                key, value_with_quotes = line[1:].split('=', 1)  # 去掉开头的 '/' 并分割键和值（带引号）
                value = value_with_quotes.strip('"')  # 去掉值两侧的引号
                current_row[key] = value

            # 检查是否是新的生物样本开始（空行或特定格式的行）
            elif (line == '' or 
                  (line.isdigit() and ':' in line and not line.startswith('/'))):
                # 如果当前行是新的生物样本开始，并且之前已经找到了标识符和属性
                if in_attributes and current_row and identifier_found:
                    rows.append(current_row)
                    current_row = {}
                    in_attributes = False
                    identifier_found = False

    # 添加最后一个样本（如果有的话）
    if in_attributes and current_row and identifier_found:
        rows.append(current_row)

    # 创建DataFrame并保存到CSV文件
    df = pd.DataFrame(rows)
    df.to_csv(output_csv_path, index=False)  # 不保存索引列

# 调用函数并指定输入和输出文件路径
input_file_path = 'biosample_result.txt'  # 输入文件路径
output_file_path = 'parsed_biosample_result.csv'  # 输出文件路径
parse_biosample_result(input_file_path, output_file_path)
