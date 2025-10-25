cat > ~/zhanping.sh << 'EOF'
#!/bin/bash
# [V18 风格] 彻底移除了 'set -e'
# 脚本现在将依赖内置的错误检查，以防止 I/O 错误导致脚本异常退出。

# ==========================================================
# 脚本全局配置
# ==========================================================
# 核心逻辑配置: 是否在文件移出后尝试删除空的子目录
DELETE_EMPTY_DIRS="true"

# ==========================================================
# 辅助函数
# ==========================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_dryrun() { echo -e "${BLUE}[试运行]${NC} $1"; }

# 帮助/用法
show_usage() {
    echo "用法: $0 [选项] [目标目录]"
    echo ""
    echo "一个将所有子目录中的文件/文件夹 '展平' (移动) 到目标目录根的脚本。"
    echo "例如：将 'Target/SubFolder/file.txt' 移动到 'Target/file.txt'。"
    echo ""
    echo "如果未提供 [目标目录]，脚本将以交互模式启动。"
    echo ""
    echo "选项:"
    echo "  -n, --dry-run    试运行。只打印将要执行的操作，不实际移动文件。"
    echo "  -h, --help       显示此帮助信息。"
}

# ==========================================================
# 核心处理函数 (V18 逻辑)
# ==========================================================
process_directory() {
    local TARGET_DIR="$1"
    local IS_DRY_RUN="$2"

    if [ "$IS_DRY_RUN" == "true" ]; then
        log_warn "--- 试运行模式 (DRY RUN) 已激活 ---"
        log_warn "将不会移动任何文件或删除目录。"
        echo ""
    fi
    
    log_info "（第1轮）正在扫描目标目录下的所有子目录..."
    log_info "目标: $TARGET_DIR"

    local moved_count=0
    declare -a SKIPPED_FILES=()
    declare -a DELETED_DIRS=()
    declare -a NON_EMPTY_DIRS=()

    # 查找 $TARGET_DIR 下的第一级子目录
    # 注意末尾的 / 确保我们只匹配目录
    for sub_dir_path in "$TARGET_DIR"/*/; do
        
        # 检查是否是一个真实存在的目录
        [ -d "$sub_dir_path" ] || continue
        
        local sub_dir_name=$(basename "$sub_dir_path")
        echo "处理子目录: $sub_dir_name"

        # 使用 find 来安全地处理所有文件名 (包括 .dotfiles)
        # -mindepth 1 -maxdepth 1 确保我们只获取子目录的第一层内容
        while IFS= read -r -d '' file_to_move; do
            
            local filename_to_move=$(basename "$file_to_move")
            local dest_file_path="$TARGET_DIR/$filename_to_move"
            
            # 检查目标位置是否已存在同名文件/目录
            if [ -e "$dest_file_path" ]; then
                if [ "$IS_DRY_RUN" == "true" ]; then
                    log_dryrun "  -> 跳过 $filename_to_move (目标 $dest_file_path 已存在)"
                else
                    echo "  -> 跳过 $filename_to_move (目标 $dest_file_path 已存在)"
                fi
                SKIPPED_FILES+=("$sub_dir_name/$filename_to_move")
            else
                if [ "$IS_DRY_RUN" == "true" ]; then
                    log_dryrun "  -> 移动 $filename_to_move 到 $TARGET_DIR/"
                    ((moved_count++))
                else
                    echo "  -> 移动 $filename_to_move 到 $TARGET_DIR/"
                    
                    # [V18] 对 mv 进行错误检查 (不使用 set -e)
                    mv -- "$file_to_move" "$dest_file_path"
                    local mv_status=$?
                    
                    if [ $mv_status -ne 0 ]; then
                        # "mv" 失败 (例如 I/O 错误), 打印错误, 但脚本会继续
                        echo "  !!!! 错误: 移动 $filename_to_move 失败 (可能是I/O错误) !!!!"
                    else
                        # "mv" 成功
                        ((moved_count++))
                    fi
                fi
            fi
        done < <(find "$sub_dir_path" -mindepth 1 -maxdepth 1 -print0)

        # （第2轮）尝试删除配置为删除的空目录
        if [ "$DELETE_EMPTY_DIRS" == "true" ]; then
            if [ "$IS_DRY_RUN" == "true" ]; then
                # 在试运行中，我们只记录意图，因为我们无法确定目录是否 *真的* 会变空
                log_dryrun "  -> (尝试) 删除目录 $sub_dir_name (仅当目录为空时)"
                DELETED_DIRS+=("$sub_dir_name (尝试)")
            else
                # 尝试删除目录， 2>/dev/null 抑制 "rmdir: failed to remove '...': Directory not empty"
                rmdir "$sub_dir_path" 2>/dev/null
                local rmdir_status=$?
                
                if [ $rmdir_status -eq 0 ]; then
                    echo "  -> 已删除空目录 $sub_dir_name"
                    DELETED_DIRS+=("$sub_dir_name")
                else
                    echo "  -> 目录 $sub_dir_name 非空 (可能因文件跳过)，已保留。"
                    NON_EMPTY_DIRS+=("$sub_dir_name")
                fi
            fi
        fi

    done

    echo "------------------------------"
    log_info "操作完成。共移动 $moved_count 个文件/文件夹。"

    # [V15] 增强的最终报告
    echo ""
    echo -e "${BLUE}--- 总结报告 ---${NC}"
    
    if [ ${#DELETED_DIRS[@]} -gt 0 ]; then
        echo -e "${GREEN}[+] 已删除 (或尝试删除) 的空目录 (${#DELETED_DIRS[@]} 个):${NC}"
        printf "  - %s\n" "${DELETED_DIRS[@]}"
    fi

    if [ ${#SKIPPED_FILES[@]} -gt 0 ]; then
        echo -e "${YELLOW}[!] 因目标已存在而跳过的文件 (${#SKIPPED_FILES[@]} 个):${NC}"
        printf "  - %s\n" "${SKIPPED_FILES[@]}"
    fi

    if [ ${#NON_EMPTY_DIRS[@]} -gt 0 ]; then
        echo -e "${RED}[!] 未删除的非空目录 (${#NON_EMPTY_DIRS[@]} 个):${NC}"
        printf "  - %s\n" "${NON_EMPTY_DIRS[@]}"
    else
        echo -e "${RED}[!] 未删除的非空目录 (0 个):${NC}"
        echo "  - (无)"
    fi
}

# ==========================================================
# 脚本主入口 (V14 逻辑)
# ==========================================================
main() {
    local TARGET_DIR=""
    local IS_DRY_RUN="false"

    # --- 参数解析 ---
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run)
                IS_DRY_RUN="true"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "未知选项: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -n "$TARGET_DIR" ]; then
                    log_error "只能指定一个目标目录。"
                    show_usage
                    exit 1
                fi
                TARGET_DIR="${1%/}"
                shift
                ;;
        esac
    done

    # --- [V14] 交互式输入 (循环验证) ---
    if [ -z "$TARGET_DIR" ]; then
        echo -e "${GREEN}=== 目录展平脚本 (交互模式) ===${NC}"
        echo -e "未指定目标目录。"
        
        while true; do
            read -rp "请输入要整理的目录: " input_dir
            TARGET_DIR="${input_dir%/}" # 获取输入并移除结尾斜杠

            if [ -z "$TARGET_DIR" ]; then
                log_error "路径不能为空，请重新输入:"
            elif [ ! -d "$TARGET_DIR" ]; then
                log_error "错误: 目标目录不存在!"
                log_error "请检查路径: $TARGET_DIR (或重新输入)"
            else
                # 路径有效, 退出循环
                break
            fi
        done
    fi

    # --- 检查路径 (此检查现在只对 *参数模式* 有效) ---
    if [ ! -d "$TARGET_DIR" ]; then
        log_error "错误: 目标目录不存在!"
        log_error "请检查路径: $TARGET_DIR"
        exit 1
    fi

    # --- 执行核心逻辑 ---
    process_directory "$TARGET_DIR" "$IS_DRY_RUN"
}

# 启动脚本
main "$@"
EOF
