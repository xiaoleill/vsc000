"""
main_window.py — FMEDA评估系统主窗口

整合所有面板和控件，实现完整的用户交互流程：
  导入 → 编辑 → 计算(SPFM+LFM) → ASIL合规判断 → 导出

布局策略：
  - 操作按钮固定在窗口底部（始终可见）
  - 上方所有内容放入可滚动画布，窗口较小时自动出现滚动条
  - 适配高DPI缩放（150%/1920x1080等效1280x720）
"""
import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from typing import Optional

from config import (
    WINDOW_TITLE, WINDOW_WIDTH, WINDOW_HEIGHT,
    WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT,
    COLOR_BG, COLOR_MODULE_BG, COLOR_FMEDA_BG,
)
from models.chip_info import ChipInfo
from services.excel_io import ExcelIO
from services.calculator import Calculator
from services.validator import Validator
from views.info_panel import InfoPanel
from views.module_panel import ModulePanel
from views.fmeda_panel import FMEDAPanel
from views.result_panel import ResultPanel


class MainWindow:
    """FMEDA评估系统主窗口"""

    def __init__(self):
        """初始化主窗口和所有子组件"""
        self._root = tk.Tk()
        self._root.title(WINDOW_TITLE)
        self._root.geometry(f"{WINDOW_WIDTH}x{WINDOW_HEIGHT}")
        self._root.minsize(WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT)
        self._root.configure(bg=COLOR_BG)

        # 状态
        self._current_filepath: Optional[str] = None
        self._spfm: Optional[float] = None
        self._lfm: Optional[float] = None
        self._compliance: Optional[dict] = None

        # 配置ttk样式
        self._setup_styles()

        # 构建UI
        self._build_ui()

        # 绑定窗口关闭事件
        self._root.protocol("WM_DELETE_WINDOW", self._on_close)

    def _setup_styles(self):
        """配置ttk自定义样式"""
        style = ttk.Style()

        style.configure("Info.TLabelframe", background=COLOR_BG)
        style.configure("Info.TLabelframe.Label", font=("微软雅黑", 9, "bold"))

        style.configure("Module.TLabelframe", background=COLOR_MODULE_BG)
        style.configure("Module.TLabelframe.Label",
                        font=("微软雅黑", 10, "bold"),
                        background=COLOR_MODULE_BG)

        style.configure("FMEDA.TLabelframe", background=COLOR_FMEDA_BG)
        style.configure("FMEDA.TLabelframe.Label",
                        font=("微软雅黑", 10, "bold"),
                        background=COLOR_FMEDA_BG)

        style.configure("Result.TLabelframe.Label",
                        font=("微软雅黑", 10, "bold"))

        style.configure("Action.TButton", font=("微软雅黑", 11, "bold"), padding=10)

        style.configure("Treeview", font=("微软雅黑", 9), rowheight=24)
        style.configure("Treeview.Heading", font=("微软雅黑", 9, "bold"))

    # =========================================================================
    # UI布局构建
    # =========================================================================

    def _build_ui(self):
        """构建完整UI布局

        结构（简洁双层 pack，无需 Canvas）：
          _root
          ├── data_area (pack TOP, fill BOTH, expand)
          │   ├── info_panel
          │   ├── control_bar
          │   └── paned (模块 + FMEDA, 自带滚动条)
          └── bottom_frame (pack BOTTOM, fill X, 固定高度)
              ├── separator
              ├── result_panel
              └── btn_bar
        """
        # ---- 数据区（占满除底部外的全部空间，随窗口缩放） ----
        data_area = ttk.Frame(self._root)
        data_area.pack(side=tk.TOP, fill=tk.BOTH, expand=True)

        self._info_panel = InfoPanel(data_area, on_change=self._on_info_changed)
        self._info_panel.pack(fill=tk.X, padx=8, pady=(8, 4))

        self._build_control_bar(data_area)

        self._build_data_panels(data_area)

        # ---- 固定底部区（始终可见，不参与缩放） ----
        bottom_frame = ttk.Frame(self._root)
        bottom_frame.pack(side=tk.BOTTOM, fill=tk.X)

        sep = ttk.Separator(bottom_frame, orient=tk.HORIZONTAL)
        sep.pack(fill=tk.X, padx=8)

        self._result_panel = ResultPanel(bottom_frame)
        self._result_panel.pack(fill=tk.X, padx=8, pady=(4, 2))

        btn_bar = ttk.Frame(bottom_frame)
        btn_bar.pack(fill=tk.X, padx=8, pady=(2, 8))
        btn_inner = ttk.Frame(btn_bar)
        btn_inner.pack()

        self._btn_import = ttk.Button(
            btn_inner, text="📥 导入Excel", style="Action.TButton",
            command=self._on_import)
        self._btn_import.pack(side=tk.LEFT, padx=5)

        self._btn_calc = ttk.Button(
            btn_inner, text="🔢 计算 SPFM/LFM", style="Action.TButton",
            command=self._on_calculate)
        self._btn_calc.pack(side=tk.LEFT, padx=5)

        self._btn_export = ttk.Button(
            btn_inner, text="📤 导出Excel", style="Action.TButton",
            command=self._on_export)
        self._btn_export.pack(side=tk.LEFT, padx=5)

        self._btn_clear = ttk.Button(
            btn_inner, text="🗑 清空", style="Action.TButton",
            command=self._on_clear)
        self._btn_clear.pack(side=tk.LEFT, padx=5)

    def _build_control_bar(self, parent: ttk.Frame):
        """构建控制栏：包含显示切换开关"""
        control_frame = ttk.Frame(parent)
        control_frame.pack(fill=tk.X, padx=8, pady=(2, 2))

        self._show_module_var = tk.BooleanVar(value=True)
        cb_module = ttk.Checkbutton(
            control_frame,
            text="显示模块信息 (Sheet 'Module')",
            variable=self._show_module_var,
            command=self._toggle_module_panel,
        )
        cb_module.pack(side=tk.LEFT, padx=(0, 20))

        self._show_fmeda_var = tk.BooleanVar(value=True)
        cb_fmeda = ttk.Checkbutton(
            control_frame,
            text="显示失效模式信息 (Sheet 'FMEDA')",
            variable=self._show_fmeda_var,
            command=self._toggle_fmeda_panel,
        )
        cb_fmeda.pack(side=tk.LEFT, padx=(0, 0))

    def _build_data_panels(self, parent: ttk.Frame):
        """构建双列数据面板容器"""
        # 不设固定高度，让数据面板随窗口缩放
        self._paned = ttk.PanedWindow(parent, orient=tk.HORIZONTAL)
        self._paned.pack(fill=tk.BOTH, expand=True, padx=8, pady=(0, 4))

        # 左侧：模块面板
        module_container = ttk.Frame(self._paned)
        self._module_panel = ModulePanel(
            module_container,
            on_data_changed=self._on_module_data_changed,
            on_selection_changed=self._on_module_selection_changed,
        )
        self._module_panel.pack(fill=tk.BOTH, expand=True)
        self._paned.add(module_container, weight=1)

        # 右侧：FMEDA面板
        fmeda_container = ttk.Frame(self._paned)
        self._fmeda_panel = FMEDAPanel(
            fmeda_container,
            on_data_changed=self._on_fmeda_data_changed,
        )
        self._fmeda_panel.pack(fill=tk.BOTH, expand=True)
        self._paned.add(fmeda_container, weight=1)

    # =========================================================================
    # 面板切换控制
    # =========================================================================

    def _toggle_module_panel(self):
        """切换模块面板的显示/隐藏"""
        if self._show_module_var.get():
            children = self._paned.panes()
            if len(children) < 2:
                container = self._module_panel.master
                self._paned.insert(0, container, weight=1)
        else:
            self._paned.forget(self._module_panel.master)

    def _toggle_fmeda_panel(self):
        """切换FMEDA面板的显示/隐藏"""
        if self._show_fmeda_var.get():
            children = self._paned.panes()
            if len(children) < 2:
                container = self._fmeda_panel.master
                self._paned.add(container, weight=1)
        else:
            self._paned.forget(self._fmeda_panel.master)

    # =========================================================================
    # 事件回调
    # =========================================================================

    def _on_info_changed(self):
        """信息面板数据变更回调"""
        pass

    def _on_module_data_changed(self):
        """模块面板数据变更回调"""
        self._spfm = None
        self._lfm = None
        self._compliance = None
        self._result_panel.clear()

    def _on_fmeda_data_changed(self):
        """FMEDA面板数据变更回调"""
        self._spfm = None
        self._lfm = None
        self._compliance = None
        self._result_panel.clear()

    def _on_module_selection_changed(self, module_name: str):
        """模块面板选中变更 → 联动FMEDA筛选"""
        self._fmeda_panel.set_filter_module(module_name)

    # =========================================================================
    # 核心操作（导入/计算/导出/清空 — 逻辑不变）
    # =========================================================================

    def _on_import(self):
        """导入Excel文件"""
        filepath = filedialog.askopenfilename(
            title="选择Excel输入文件",
            filetypes=[("Excel文件", "*.xlsx *.xlsm"), ("所有文件", "*.*")],
        )
        if not filepath:
            return

        try:
            chip_info, modules, fmeda_list = ExcelIO.import_excel(filepath)
            self._current_filepath = filepath

            self._info_panel.set_values(
                project=chip_info.project,
                chip_area=chip_info.chip_area,
                lambda_chip=chip_info.lambda_chip,
                m_num=chip_info.m_num,
                asil=chip_info.asil,
            )

            self._module_panel.set_modules(modules)
            self._fmeda_panel.set_fmeda_list(fmeda_list)

            self._spfm = None
            self._lfm = None
            self._compliance = None
            self._result_panel.clear()

            messagebox.showinfo(
                "导入成功",
                f"已成功导入数据：\n"
                f"  项目：{chip_info.project}\n"
                f"  ASIL等级：{chip_info.asil}\n"
                f"  模块数：{len(modules)}\n"
                f"  失效模式数：{len(fmeda_list)}",
            )

        except FileNotFoundError as e:
            messagebox.showerror("导入失败", str(e))
        except ValueError as e:
            messagebox.showerror("导入失败", f"数据格式错误：{e}")
        except Exception as e:
            messagebox.showerror("导入失败", f"未知错误：{e}")

    def _on_calculate(self):
        """执行SPFM和LFM计算"""
        chip_info = ChipInfo(
            project=self._info_panel.get_project(),
            chip_area=self._info_panel.get_chip_area(),
            lambda_chip=self._info_panel.get_lambda_chip(),
            m_num=self._info_panel.get_m_num(),
            asil=self._info_panel.get_asil(),
        )

        modules = self._module_panel.get_modules()
        fmeda_list = self._fmeda_panel.get_fmeda_list()

        ok, errors = Validator.validate_all(
            expected_m_num=chip_info.m_num,
            modules=modules,
            fmeda_list=fmeda_list,
        )

        if not ok:
            error_msg = "数据校验未通过，请修正以下问题：\n\n"
            error_msg += "\n".join(f"  • {e}" for e in errors)
            messagebox.showerror("校验失败", error_msg)
            return

        try:
            spfm, lfm = Calculator.compute_all(
                lambda_chip=chip_info.lambda_chip,
                modules=modules,
                fmeda_list=fmeda_list,
            )
            compliance = Calculator.check_asil_compliance(spfm, lfm, chip_info.asil)
        except Exception as e:
            messagebox.showerror("计算错误", f"计算过程中发生错误：{e}")
            return

        self._module_panel.set_modules(modules)
        self._module_panel.update_lambda_m()

        self._fmeda_panel.set_fmeda_list(fmeda_list)
        self._fmeda_panel.update_lambda_results()

        self._spfm = spfm
        self._lfm = lfm
        self._compliance = compliance
        self._result_panel.set_results(spfm, lfm, chip_info.asil, compliance)

        self._info_panel.set_values(
            project=chip_info.project,
            chip_area=chip_info.chip_area,
            lambda_chip=chip_info.lambda_chip,
            m_num=len(modules),
            asil=chip_info.asil,
        )

        total_lambda_r = sum(fm.lambda_r for fm in fmeda_list)
        total_lambda_l = sum(fm.lambda_latent for fm in fmeda_list)
        spfm_status = compliance['SPFM']['label']
        lfm_status = compliance['LFM']['label']

        messagebox.showinfo(
            "计算完成",
            f"计算完成 (ASIL {chip_info.asil})：\n\n"
            f"  SPFM = {spfm * 100:.2f}%  [{spfm_status}]\n"
            f"  LFM  = {lfm * 100:.2f}%  [{lfm_status}]\n"
            f"  λ_R_sum (总残余失效) = {total_lambda_r:.2f} FIT\n"
            f"  λ_L_sum (总潜在失效) = {total_lambda_l:.2f} FIT",
        )

    def _on_export(self):
        """导出计算结果到Excel"""
        if self._spfm is None or self._lfm is None:
            if not messagebox.askyesno(
                "尚未计算",
                "当前还没有计算结果。\n是否先执行计算后再导出？"
            ):
                return
            self._on_calculate()
            if self._spfm is None:
                return

        default_name = "fmeda_result.xlsx"
        if self._current_filepath:
            import os
            base = os.path.splitext(self._current_filepath)[0]
            default_name = f"{base}_result.xlsx"

        filepath = filedialog.asksaveasfilename(
            title="导出计算结果",
            defaultextension=".xlsx",
            initialfile=default_name,
            filetypes=[("Excel文件", "*.xlsx"), ("所有文件", "*.*")],
        )
        if not filepath:
            return

        try:
            chip_info = ChipInfo(
                project=self._info_panel.get_project(),
                chip_area=self._info_panel.get_chip_area(),
                lambda_chip=self._info_panel.get_lambda_chip(),
                m_num=self._info_panel.get_m_num(),
                asil=self._info_panel.get_asil(),
            )
            modules = self._module_panel.get_modules()
            fmeda_list = self._fmeda_panel.get_fmeda_list()

            ExcelIO.export_excel(
                filepath, chip_info, modules, fmeda_list,
                self._spfm, self._lfm,
            )
            messagebox.showinfo("导出成功", f"计算结果已成功导出至：\n{filepath}")

        except Exception as e:
            messagebox.showerror("导出失败", f"导出过程中发生错误：{e}")

    def _on_clear(self):
        """清空所有面板数据"""
        if messagebox.askyesno("确认清空", "确定要清空所有数据吗？此操作不可撤销。"):
            self._module_panel.clear()
            self._fmeda_panel.clear()
            self._result_panel.clear()
            self._spfm = None
            self._lfm = None
            self._compliance = None
            self._current_filepath = None

    def _on_close(self):
        """关闭窗口"""
        self._root.destroy()

    # =========================================================================
    # 启动
    # =========================================================================

    def run(self):
        """启动Tkinter主循环"""
        self._root.mainloop()
