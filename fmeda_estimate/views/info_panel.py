"""
info_panel.py — 芯片基本信息面板

显示和编辑芯片级别参数：项目名称、芯片面积、总体失效率、模块数目、ASIL等级。
"""
import tkinter as tk
from tkinter import ttk
from typing import Callable, Optional

from config import (
    COLOR_INFO_BG, DEFAULT_PROJECT, DEFAULT_CHIP_AREA,
    DEFAULT_LAMBDA_CHIP, DEFAULT_M_NUM, DEFAULT_ASIL, ASIL_LEVELS
)


class InfoPanel(ttk.LabelFrame):
    """芯片基本信息面板

    包含5个可编辑字段：
      - project: 芯片名称（字符串）
      - chip_area: 芯片总面积（实数）
      - lambda_chip: 芯片总体失效率（FIT）
      - m_num: 模块数目（整数）
      - asil: ASIL等级（A/B/C/D下拉选择）
    """

    def __init__(self, parent, on_change: Optional[Callable] = None):
        """初始化信息面板

        Args:
            parent: 父级Tkinter容器
            on_change: 数据变更时的回调函数（可选接收asil参数）
        """
        super().__init__(parent, text="芯片基本信息 (Sheet 'Info')", padding=10)
        self.on_change = on_change
        self.configure(style="Info.TLabelframe")

        # ---- 内部变量 ----
        self._project_var = tk.StringVar(value=DEFAULT_PROJECT)
        self._chip_area_var = tk.StringVar(value=f"{DEFAULT_CHIP_AREA:.2f}")
        self._lambda_chip_var = tk.StringVar(value=f"{DEFAULT_LAMBDA_CHIP:.2f}")
        self._m_num_var = tk.StringVar(value=str(DEFAULT_M_NUM))
        self._asil_var = tk.StringVar(value=DEFAULT_ASIL)

        self._build_ui()

    def _build_ui(self):
        """构建面板内部UI布局（两行，上行4字段，下行ASIL）"""
        frame = ttk.Frame(self)
        frame.pack(fill=tk.X, expand=True)

        # 配置网格列权重
        for i in range(10):
            frame.columnconfigure(i, weight=1)

        # ==== 第一行：4个文本字段 ====
        base_row = 0

        ttk.Label(frame, text="芯片名称(project):").grid(
            row=base_row, column=0, sticky=tk.W, padx=(0, 2))
        entry_project = ttk.Entry(frame, textvariable=self._project_var, width=15)
        entry_project.grid(row=base_row, column=1, sticky=tk.W, padx=(0, 10))

        ttk.Label(frame, text="芯片总面积(chip_area):").grid(
            row=base_row, column=2, sticky=tk.W, padx=(0, 2))
        entry_area = ttk.Entry(frame, textvariable=self._chip_area_var, width=12)
        entry_area.grid(row=base_row, column=3, sticky=tk.W, padx=(0, 10))

        ttk.Label(frame, text="总体失效率(λ_chip/FIT):").grid(
            row=base_row, column=4, sticky=tk.W, padx=(0, 2))
        entry_lambda = ttk.Entry(frame, textvariable=self._lambda_chip_var, width=12)
        entry_lambda.grid(row=base_row, column=5, sticky=tk.W, padx=(0, 10))

        ttk.Label(frame, text="模块数目(M_num):").grid(
            row=base_row, column=6, sticky=tk.W, padx=(0, 2))
        entry_mnum = ttk.Entry(frame, textvariable=self._m_num_var, width=8)
        entry_mnum.grid(row=base_row, column=7, sticky=tk.W, padx=(0, 10))

        # ==== ASIL等级下拉框（同行第8-9列） ====
        ttk.Label(frame, text="ASIL等级:").grid(
            row=base_row, column=8, sticky=tk.W, padx=(0, 2))
        combo_asil = ttk.Combobox(
            frame, textvariable=self._asil_var, values=ASIL_LEVELS,
            state="readonly", width=5
        )
        combo_asil.grid(row=base_row, column=9, sticky=tk.W)

        # 绑定变更事件
        for var in [self._project_var, self._chip_area_var,
                     self._lambda_chip_var, self._m_num_var]:
            var.trace_add("write", lambda *args: self._notify_change())
        self._asil_var.trace_add("write", lambda *args: self._notify_change())

    def _notify_change(self):
        """通知外部数据已变更"""
        if self.on_change:
            self.on_change()

    # =========================================================================
    # 数据存取接口
    # =========================================================================

    def get_project(self) -> str:
        """获取芯片名称"""
        return self._project_var.get().strip()

    def get_chip_area(self) -> float:
        """获取芯片总面积"""
        try:
            return float(self._chip_area_var.get().strip())
        except ValueError:
            return DEFAULT_CHIP_AREA

    def get_lambda_chip(self) -> float:
        """获取芯片总体失效率"""
        try:
            return float(self._lambda_chip_var.get().strip())
        except ValueError:
            return DEFAULT_LAMBDA_CHIP

    def get_m_num(self) -> int:
        """获取模块数目"""
        try:
            return int(self._m_num_var.get().strip())
        except ValueError:
            return DEFAULT_M_NUM

    def get_asil(self) -> str:
        """获取ASIL等级"""
        return self._asil_var.get().strip().upper()

    def set_values(self, project: str, chip_area: float,
                   lambda_chip: float, m_num: int, asil: str = DEFAULT_ASIL):
        """批量设置面板字段值（用于导入后填充）"""
        self._project_var.set(project)
        self._chip_area_var.set(f"{chip_area:.2f}")
        self._lambda_chip_var.set(f"{lambda_chip:.2f}")
        self._m_num_var.set(str(m_num))
        self._asil_var.set(asil if asil in ASIL_LEVELS else DEFAULT_ASIL)
