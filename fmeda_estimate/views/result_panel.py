"""
result_panel.py — SPFM/LFM计算结果展示面板

紧凑展示SPFM和LFM计算结果及ASIL合规判定（PASS/FAIL）。
"""
import tkinter as tk
from tkinter import ttk

from config import (
    COLOR_RESULT_BG, COLOR_RESULT_TEXT, COLOR_PASS, COLOR_FAIL, COLOR_NA,
    PERCENT_MULTIPLIER, DECIMAL_PLACES
)


class ResultPanel(ttk.LabelFrame):
    """SPFM/LFM结果展示面板（紧凑型）"""

    def __init__(self, parent):
        """初始化结果面板"""
        super().__init__(parent, text="ISO 26262 指标计算结果", padding=(10, 5))
        # 移除粉红色背景样式，使用默认外观
        self._spfm_var = tk.StringVar(value="--")
        self._spfm_status_var = tk.StringVar(value="")
        self._lfm_var = tk.StringVar(value="--")
        self._lfm_status_var = tk.StringVar(value="")
        self._asil_var = tk.StringVar(value="")

        self._build_ui()

    def _build_ui(self):
        """构建紧凑的双指标结果展示UI"""
        frame = ttk.Frame(self)
        frame.pack(expand=True, fill=tk.BOTH)

        # 使用单行紧凑布局：ASIL | SPFM: XX.XX% [PASS] | LFM: XX.XX% [PASS]
        # ASIL 标签
        ttk.Label(frame, text="ASIL等级:", font=("微软雅黑", 9)).pack(
            side=tk.LEFT, padx=(0, 2))
        ttk.Label(frame, textvariable=self._asil_var,
                  font=("微软雅黑", 10, "bold")).pack(
            side=tk.LEFT, padx=(0, 15))

        # 分隔符
        ttk.Separator(frame, orient=tk.VERTICAL).pack(
            side=tk.LEFT, fill=tk.Y, padx=5, pady=2)

        # SPFM
        ttk.Label(frame, text="SPFM:", font=("微软雅黑", 9)).pack(
            side=tk.LEFT, padx=(10, 2))
        tk.Label(frame, textvariable=self._spfm_var,
                 font=("微软雅黑", 14, "bold"),
                 fg=COLOR_RESULT_TEXT, bg=COLOR_RESULT_BG).pack(
            side=tk.LEFT, padx=(0, 2))
        self._spfm_status_label = tk.Label(
            frame, textvariable=self._spfm_status_var,
            font=("微软雅黑", 10, "bold"),
            bg=COLOR_RESULT_BG,
        )
        self._spfm_status_label.pack(side=tk.LEFT, padx=(2, 15))

        # 分隔符
        ttk.Separator(frame, orient=tk.VERTICAL).pack(
            side=tk.LEFT, fill=tk.Y, padx=5, pady=2)

        # LFM
        ttk.Label(frame, text="LFM:", font=("微软雅黑", 9)).pack(
            side=tk.LEFT, padx=(10, 2))
        tk.Label(frame, textvariable=self._lfm_var,
                 font=("微软雅黑", 14, "bold"),
                 fg=COLOR_RESULT_TEXT, bg=COLOR_RESULT_BG).pack(
            side=tk.LEFT, padx=(0, 2))
        self._lfm_status_label = tk.Label(
            frame, textvariable=self._lfm_status_var,
            font=("微软雅黑", 10, "bold"),
            bg=COLOR_RESULT_BG,
        )
        self._lfm_status_label.pack(side=tk.LEFT, padx=(2, 0))

    def set_results(self, spfm: float, lfm: float, asil: str, compliance: dict):
        """设置SPFM、LFM结果及合规判定"""
        self._asil_var.set(f"ASIL {asil}")

        self._spfm_var.set(f"{spfm * PERCENT_MULTIPLIER:.{DECIMAL_PLACES}f}%")
        self._set_status(self._spfm_status_var, self._spfm_status_label,
                         compliance['SPFM'])

        self._lfm_var.set(f"{lfm * PERCENT_MULTIPLIER:.{DECIMAL_PLACES}f}%")
        self._set_status(self._lfm_status_var, self._lfm_status_label,
                         compliance['LFM'])

    def _set_status(self, var: tk.StringVar, label: tk.Label, info: dict):
        """设置单个指标的状态显示（无✓/✗符号）"""
        var.set(info['label'])
        if info['pass'] is True:
            label.configure(fg=COLOR_PASS)
        elif info['pass'] is False:
            label.configure(fg=COLOR_FAIL)
        else:
            label.configure(fg=COLOR_NA)

    def clear(self):
        """清除结果"""
        self._spfm_var.set("--")
        self._spfm_status_var.set("")
        self._lfm_var.set("--")
        self._lfm_status_var.set("")
        self._asil_var.set("")
