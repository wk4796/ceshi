#!/usr/bin/env python3

# -*- coding: utf-8 -*-

import os
import re
import time

# TODO: 请将 '/你的漫画文件夹' 替换为你的图片所在的实际路径。
# 注意：在 Linux 路径中，使用正斜杠 '/'。
FOLDER_PATH = '/xiazai/9/'

# TODO: 请在这里输入每话的平均页数。
# 这是一个关键参数，将决定脚本如何计算话数和页数。
PAGES_PER_EPISODE = 16

def rename_manga_files():
    """
    遍历指定文件夹中的JPG图片，并按照“第[话数]-第[页数].jpg”的格式重新命名。
    """
    if not os.path.isdir(FOLDER_PATH):
        print(f"错误：指定的文件夹不存在！'{FOLDER_PATH}'")
        return

    files = [f for f in os.listdir(FOLDER_PATH) if f.lower().endswith('.jpg')]
    
    files.sort(key=lambda f: int(re.findall(r'\d+', f)[0]) if re.findall(r'\d+', f) else 0)

    if not files:
        print("错误：在指定的文件夹中没有找到任何 .jpg 文件。")
        return

    file_count = len(files)
    print(f"找到了 {file_count} 个图片文件，开始重命名...")

    for i, old_file_name in enumerate(files):
        current_file_number = i + 1
        
        current_episode = (current_file_number - 1) // PAGES_PER_EPISODE + 1
        current_page = (current_file_number - 1) % PAGES_PER_EPISODE + 1

        new_file_name = f"第{current_episode:03d}话-第{current_page:02d}页.jpg"

        old_path = os.path.join(FOLDER_PATH, old_file_name)
        new_path = os.path.join(FOLDER_PATH, new_file_name)

        if os.path.exists(new_path) and old_path != new_path:
            print(f"警告：文件 '{new_file_name}' 已存在，跳过重命名 '{old_file_name}'")
            continue

        try:
            os.rename(old_path, new_path)
            print(f"重命名成功： '{old_file_name}' -> '{new_file_name}'")
        except Exception as e:
            print(f"重命名失败： '{old_file_name}'")
            print(f"错误信息：{e}")

    print("所有文件重命名操作完成！")

if __name__ == "__main__":
    rename_manga_files()
