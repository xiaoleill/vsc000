"""
main.py — FMEDA评估系统入口

基于ISO 26262的硬件架构指标SPFM（单点故障覆盖率）计算工具。
提供Tkinter图形界面，支持Excel数据导入/导出和在线编辑计算。

用法：
    python main.py

依赖：
    - Python 3.7+
    - tkinter (标准库)
    - openpyxl (pip install openpyxl)
"""
import sys
import os

# 确保项目根目录在搜索路径中
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from views.main_window import MainWindow


def main():
    """应用程序主入口"""
    app = MainWindow()
    app.run()


if __name__ == "__main__":
    main()
