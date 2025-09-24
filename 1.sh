#!/usr/bin/env python3

# -*- coding: utf-8 -*-

import os
import re

# TODO: 请将 '/你的漫画文件夹' 替换为你的图片所在的实际路径。
# 注意：在 Linux 路径中，使用正斜杠 '/'。
FOLDER_PATH = '/xiazai/9/'

# TODO: 请设置第一话的第一页以什么数字开始，1 或 2。
START_PAGE_NUMBER = 1

def rename_manga_files():
    """
    遍历指定文件夹中的JPG图片，并根据文件名中的数字序列重新命名。
    """
    if not os.path.isdir(FOLDER_PATH):
        print(f"错误：指定的文件夹不存在！'{FOLDER_PATH}'")
        return

    files = [f for f in os.listdir(FOLDER_PATH) if f.lower().endswith('.jpg')]

    # 按照文件名中的第一个数字序列进行自然排序
    files.sort(key=lambda f: int(re.findall(r'(\d+)-\d+\.jpg', f)[0]))

    if not files:
        print("错误：在指定的文件夹中没有找到任何 .jpg 文件。")
        return

    print(f"找到了 {len(files)} 个图片文件，开始重命名...")

    current_episode = 1
    current_page = START_PAGE_NUMBER

    for i, old_file_name in enumerate(files):
        match = re.search(r'(\d+)-(\d+)\.jpg', old_file_name)
        if match:
            first_number = int(match.group(1))
            second_number = int(match.group(2))

            # 判断话数切换的条件：第二个数字为1或2，并且第一个数字不为1
            # 这样可以排除掉第一话的特殊情况（0001-002）
            if i > 0 and (second_number == 1 or second_number == 2) and (first_number != 1):
                current_episode += 1
                current_page = 1
            
            new_file_name = f"第{current_episode:03d}话-第{current_page:02d}页.jpg"
            current_page += 1

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
