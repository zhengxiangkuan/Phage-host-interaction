#!/bin/bash

# 默认输出目录
output_dir="output"

# 检查是否指定了输出目录
if [ "$1" == "-d" ] && [ -n "$2" ]; then
    output_dir="$2"
    shift 2
fi

# 获取所有CSV文件
files=( "$@" )
if [ ${#files[@]} -eq 0 ]; then
    files=( *.csv )
fi

# 如果没有找到文件
if [ ${#files[@]} -eq 0 ]; then
    echo "错误：没有找到CSV文件" >&2
    exit 1
fi

# 创建输出目录（如果不存在）
mkdir -p "$output_dir"

# 使用临时文件存储MD5和文件名
tmpfile=$(mktemp)

# 计算文件MD5并存储
for file in "${files[@]}"; do
    if [ ! -f "$file" ]; then
        continue
    fi
    md5=$(md5sum "$file" | awk '{print $1}')
    printf "%s\t%s\n" "$md5" "$file" >> "$tmpfile"
done

# 按MD5排序文件
sort "$tmpfile" > "${tmpfile}.sorted"

# 分组文件
declare -a groups
declare -a group_sizes
current_md5=""
group_index=-1

while IFS=$'\t' read -r md5 file; do
    if [ "$md5" != "$current_md5" ]; then
        ((group_index++))
        current_md5="$md5"
        groups[group_index]="$file"
        group_sizes[group_index]=1
    else
        groups[group_index]+=$'\n'"$file"
        ((group_sizes[group_index]++))
    fi
done < "${tmpfile}.sorted"

# 按分组大小排序（从大到小）
mapfile -t sorted_indices < <(
    for i in "${!group_sizes[@]}"; do
        printf "%s\t%s\n" "${group_sizes[i]}" "$i"
    done | sort -rn -k1 | cut -f2
)

# 创建分组文件夹并复制文件
echo "创建分组文件夹并复制文件..."
for ((j=0; j<${#sorted_indices[@]}; j++)); do
    group_num=$((j+1))
    group_name="group$group_num"
    group_path="$output_dir/$group_name"
    
    # 创建分组文件夹
    mkdir -p "$group_path"
    
    # 获取该分组的所有文件
    i=${sorted_indices[j]}
    IFS=$'\n' read -d '' -ra group_files <<< "${groups[i]}"
    
    # 复制文件到分组文件夹
    for file in "${group_files[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$group_path/"
            echo "  复制: $file -> $group_path/"
        fi
    done
done

# 创建汇总表格
output_csv="$output_dir/summary.csv"
echo "创建汇总表格: $output_csv"

{
    # 打印表头
    echo -n "分组名称"
    for ((j=1; j<=${#sorted_indices[@]}; j++)); do
        echo -n ",group$j"
    done
    echo
    
    # 打印样本个数行
    echo -n "样本个数"
    for j in "${!sorted_indices[@]}"; do
        i=${sorted_indices[j]}
        echo -n ",${group_sizes[i]}"
    done
    echo
} > "$output_csv"

# 清理临时文件
rm -f "$tmpfile" "${tmpfile}.sorted"

# 输出统计信息
echo "处理完成!"
echo "输出目录: $output_dir"
echo "分组数量: ${#sorted_indices[@]}"
echo "总文件数: ${#files[@]}"
