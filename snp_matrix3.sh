#!/bin/bash

# 定义变异类型
types=("snp" "mnp" "ins" "del" "complex")

# 初始化临时文件
for t in "${types[@]}"; do
    > "$t.tmp"
done

# 创建排序后的文件列表临时文件
file_list_temp=$(mktemp)
printf "%s\n" *.csv | sort > "$file_list_temp"

# 处理每个CSV文件
for file in *.csv; do
    filename=$(basename "$file")
    # 跳过标题行，处理数据行
    tail -n +2 "$file" | while IFS=, read -r chrom pos type ref alt _; do
        # 检查变异类型是否在目标列表中
        for t in "${types[@]}"; do
            if [[ "$type" == "$t" ]]; then
                # 写入格式: 类型,位置,参考碱基,文件名,替代碱基
                echo "$t,$pos,$ref,$filename,$alt" >> "$t.tmp"
                break
            fi
        done
    done
done

# 为每种变异类型生成矩阵
for t in "${types[@]}"; do
    if [[ ! -s "$t.tmp" ]]; then
        echo "No $t variants found. Skipping $t matrix."
        continue
    fi
    
    # 生成矩阵文件
    awk -F, -v type="$t" -v temp_file="$file_list_temp" '
    BEGIN {
        # 从临时文件读取所有文件名
        while ((getline < temp_file) > 0) {
            files[$0] = 1
        }
        close(temp_file)
    }
    {
        pos = $2
        ref = $3
        file = $4
        alt = $5
        
        # 创建复合键 (位置+参考碱基)
        key = pos "," ref
        
        # 记录参考碱基
        refs[key] = ref
        
        # 存储ALT值
        alt_map[key][file] = alt
    }
    END {
        # 获取排序后的文件名
        file_count = asorti(files, sorted_files)
        
        # 收集所有位置
        for (key in refs) {
            split(key, parts, ",")
            pos_val = parts[1]
            positions[pos_val] = 1
        }
        # 按数值排序位置
        pos_count = asorti(positions, sorted_positions, "@ind_num_asc")
        
        # 打印表头 (文件名)
        printf "REF\tPOS"
        for (i = 1; i <= file_count; i++) {
            printf "\t%s", sorted_files[i]
        }
        printf "\tMode\tFrequency\n"   # 添加最后两列
        
        # 打印矩阵内容
        for (p = 1; p <= pos_count; p++) {
            pos_val = sorted_positions[p]
            # 查找该位置对应的所有参考碱基
            for (key in refs) {
                split(key, parts, ",")
                if (parts[1] == pos_val) {
                    ref_val = refs[key]
                    printf "%s\t%s", ref_val, pos_val
                    
                    # 准备统计频率
                    delete freq
                    
                    # 为每个文件打印ALT值，空白则填充REF
                    for (f = 1; f <= file_count; f++) {
                        file_name = sorted_files[f]
                        if (alt_map[key][file_name]) {
                            alt_val = alt_map[key][file_name]
                            printf "\t%s", alt_val
                        } else {
                            printf "\t%s", ref_val  # 空白处填充参考碱基
                            alt_val = ref_val
                        }
                        # 统计频率
                        freq[alt_val]++
                    }
                    
                    # 找出出现频率最高的碱基
                    max_count = 0
                    mode_value = ""
                    for (value in freq) {
                        if (freq[value] > max_count) {
                            max_count = freq[value]
                            mode_value = value
                        }
                    }
                    # 计算频率百分比
                    freq_percent = (max_count / file_count) * 100
                    
                    # 添加最后两列
                    printf "\t%s\t%.2f%%\n", mode_value, freq_percent
                }
            }
        }
    }' "$t.tmp" > "${t}_matrix.tsv"
    
    echo "Created ${t}_matrix.tsv"
done

# 清理临时文件
rm -f *.tmp
rm -f "$file_list_temp"
