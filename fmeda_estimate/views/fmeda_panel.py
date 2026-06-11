"""
fmeda_panel.py — FMEDA失效模式面板

显示各模块的失效模式、失效占比、DC、DC_LF及残余/潜在失效率。
支持：
  - 双显示模式：全部显示（合并单元格视觉）/ 按模块筛选
  - 双击编辑 FMD%、DC%、DC_LF%
  - + 添加失效模式 / − 删除失效模式
"""
import tkinter as tk
from tkinter import ttk, messagebox
from typing import List, Callable, Optional

from config import PERCENT_MULTIPLIER, DECIMAL_PLACES
from models.fmeda import FailureMode


# 列索引常量
COL_FM_MODULE = 0    # 模块名称
COL_FM_NAME = 1      # 失效模式名称
COL_FM_PCT = 2       # 失效占比 FMD%
COL_FM_DC = 3        # 诊断覆盖率 DC%
COL_FM_DC_LF = 4     # 潜在故障DC DC_LF%
COL_FM_LAMBDA_R = 5  # 残余失效率 λ_R
COL_FM_LAMBDA_L = 6  # 潜在失效率 λ_L

# 可编辑列索引
EDITABLE_COLS = {COL_FM_PCT, COL_FM_DC, COL_FM_DC_LF}


class FMEDAPanel(ttk.LabelFrame):
    """FMEDA失效模式面板

    支持全部显示和按模块筛选两种模式。
    """

    def __init__(self, parent, on_data_changed: Optional[Callable] = None):
        """初始化FMEDA面板

        Args:
            parent: 父级Tkinter容器
            on_data_changed: 数据变更回调
        """
        super().__init__(parent, text="失效模式信息 (Sheet 'FMEDA')", padding=5)
        self.on_data_changed = on_data_changed

        # 内部数据
        self._all_fmeda: List[FailureMode] = []  # 全量FMEDA数据
        self._display_mode = tk.StringVar(value="all")  # "all" / "filtered"
        self._filter_module: str = ""  # 筛选模式下目标模块名
        self._fm_counter = 0  # 失效模式自动命名计数器

        # 编辑状态
        self._edit_entry = None
        self._edit_row = None
        self._edit_col = None

        self._build_ui()

    def _build_ui(self):
        """构建完整UI：控制栏 + Treeview + 滚动条"""
        # ---- 顶部控制栏：显示模式 Radio + +/- 按钮 ----
        ctrl_frame = ttk.Frame(self)
        ctrl_frame.pack(fill=tk.X, padx=2, pady=(2, 2))

        # +/- 按钮（左侧）
        self._btn_add = ttk.Button(ctrl_frame, text="+", width=3,
                                   command=self._on_add_fm)
        self._btn_add.pack(side=tk.LEFT, padx=(0, 2))

        self._btn_del = ttk.Button(ctrl_frame, text="−", width=3,
                                   command=self._on_del_fm)
        self._btn_del.pack(side=tk.LEFT, padx=(0, 10))

        # 分隔符
        ttk.Separator(ctrl_frame, orient=tk.VERTICAL).pack(
            side=tk.LEFT, fill=tk.Y, padx=5)

        # 显示模式 Radio 按钮（右侧）
        ttk.Radiobutton(
            ctrl_frame, text="全部显示", variable=self._display_mode,
            value="all", command=self._on_mode_changed
        ).pack(side=tk.LEFT, padx=(10, 5))

        ttk.Radiobutton(
            ctrl_frame, text="按模块筛选", variable=self._display_mode,
            value="filtered", command=self._on_mode_changed
        ).pack(side=tk.LEFT, padx=(5, 10))

        # 筛选提示标签
        self._filter_label = ttk.Label(ctrl_frame, text="", foreground="gray")
        self._filter_label.pack(side=tk.LEFT)

        # ---- Treeview ----
        container = ttk.Frame(self)
        container.pack(fill=tk.BOTH, expand=True)

        columns = ("模块(M)", "失效模式(FM)", "失效占比(FMD%)",
                   "诊断覆盖率(DC%)", "潜在故障DC(DC_LF%)",
                   "残余失效(λ_R/FIT)", "潜在失效(λ_L/FIT)")
        self._tree = ttk.Treeview(
            container, columns=columns, show="headings",
            height=10, selectmode="browse",
        )

        # 列标题
        self._tree.heading("模块(M)", text="模块(M)")
        self._tree.heading("失效模式(FM)", text="失效模式(FM)")
        self._tree.heading("失效占比(FMD%)", text="失效占比(FMD%)")
        self._tree.heading("诊断覆盖率(DC%)", text="诊断覆盖率(DC%)")
        self._tree.heading("潜在故障DC(DC_LF%)", text="潜在故障DC(DC_LF%)")
        self._tree.heading("残余失效(λ_R/FIT)", text="残余失效(λ_R/FIT)")
        self._tree.heading("潜在失效(λ_L/FIT)", text="潜在失效(λ_L/FIT)")

        # 列宽
        self._tree.column("模块(M)", width=90, anchor="center")
        self._tree.column("失效模式(FM)", width=100, anchor="center")
        self._tree.column("失效占比(FMD%)", width=105, anchor="center")
        self._tree.column("诊断覆盖率(DC%)", width=105, anchor="center")
        self._tree.column("潜在故障DC(DC_LF%)", width=115, anchor="center")
        self._tree.column("残余失效(λ_R/FIT)", width=115, anchor="center")
        self._tree.column("潜在失效(λ_L/FIT)", width=115, anchor="center")

        # 滚动条
        scrollbar_y = ttk.Scrollbar(container, orient=tk.VERTICAL,
                                    command=self._tree.yview)
        scrollbar_x = ttk.Scrollbar(container, orient=tk.HORIZONTAL,
                                    command=self._tree.xview)
        self._tree.configure(yscrollcommand=scrollbar_y.set,
                             xscrollcommand=scrollbar_x.set)

        self._tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar_y.pack(side=tk.RIGHT, fill=tk.Y)
        scrollbar_x.pack(side=tk.BOTTOM, fill=tk.X)

        # 绑定事件
        self._tree.bind("<Double-1>", self._on_double_click)

    # =========================================================================
    # 显示模式控制
    # =========================================================================

    def _on_mode_changed(self):
        """显示模式切换"""
        self._refresh_display()

    def set_filter_module(self, module_name: str):
        """设置筛选目标模块（从Module面板选中回调）

        Args:
            module_name: 目标模块名，空字符串表示取消筛选
        """
        self._filter_module = module_name
        if self._display_mode.get() == "filtered":
            self._filter_label.config(
                text=f"当前筛选: {module_name}" if module_name else "未选择模块"
            )
            self._refresh_display()

    def _refresh_display(self):
        """根据当前显示模式刷新Treeview内容"""
        # 先同步Treeview当前编辑可能未保存的数据
        self._sync_to_fmeda()

        # 清空Treeview
        for item in self._tree.get_children():
            self._tree.delete(item)

        # 确定要显示的数据
        mode = self._display_mode.get()
        if mode == "filtered" and self._filter_module:
            display_list = [fm for fm in self._all_fmeda
                            if fm.module_name == self._filter_module]
            self._filter_label.config(text=f"当前筛选: {self._filter_module}")
        else:
            display_list = self._all_fmeda
            self._filter_label.config(text="")

        if not display_list:
            return

        # 分组填充（含合并单元格视觉效果）
        # 按模块名分组
        prev_module = None
        for fm in display_list:
            # 合并单元格视觉效果：同模块名下非首行显示空模块名
            show_module = fm.module_name if fm.module_name != prev_module else ""
            prev_module = fm.module_name

            self._tree.insert("", tk.END, values=(
                show_module,
                fm.fm_name,
                f"{fm.fm_pct * PERCENT_MULTIPLIER:.{DECIMAL_PLACES}f}%",
                f"{fm.dc * PERCENT_MULTIPLIER:.{DECIMAL_PLACES}f}%",
                f"{fm.dc_lf * PERCENT_MULTIPLIER:.{DECIMAL_PLACES}f}%",
                f"{fm.lambda_r:.{DECIMAL_PLACES}f}" if fm.lambda_r else "-",
                f"{fm.lambda_latent:.{DECIMAL_PLACES}f}" if fm.lambda_latent else "-",
            ))

    # =========================================================================
    # +/- 按钮操作
    # =========================================================================

    def _on_add_fm(self):
        """添加新失效模式行"""
        self._sync_to_fmeda()  # 确保all_fmeda最新

        # 确定新FM所属模块
        mode = self._display_mode.get()
        if mode == "filtered" and self._filter_module:
            target_module = self._filter_module
        else:
            # 全部模式：尝试使用Module面板选中的模块
            if self._all_fmeda:
                # 用已有数据的最后一个模块
                target_module = self._all_fmeda[-1].module_name
            else:
                target_module = "M0"

        self._fm_counter += 1
        existing_count = sum(1 for fm in self._all_fmeda
                            if fm.module_name == target_module)
        new_fm_name = f"FM{existing_count}"

        new_fm = FailureMode(
            module_name=target_module,
            fm_name=new_fm_name,
            fm_pct=0.0,
            dc=0.0,
            dc_lf=0.0,
        )
        self._all_fmeda.append(new_fm)
        self._refresh_display()
        self._notify_change()

    def _on_del_fm(self):
        """删除选中的失效模式行"""
        selected = self._tree.selection()
        if not selected:
            messagebox.showwarning("提示", "请先在失效模式列表中选择要删除的条目。")
            return

        item = selected[0]
        values = self._tree.item(item, "values")
        fm_name = values[COL_FM_NAME]
        module_name = values[COL_FM_MODULE]

        # 如果模块名为空（合并单元格），回溯找实际模块名
        if not module_name:
            # 向前查找同模块的行
            all_items = self._tree.get_children()
            idx = all_items.index(item)
            for i in range(idx, -1, -1):
                prev_vals = self._tree.item(all_items[i], "values")
                if prev_vals[COL_FM_MODULE]:
                    module_name = prev_vals[COL_FM_MODULE]
                    break

        if not messagebox.askyesno("确认删除",
                                   f"确定要删除「{module_name}/{fm_name}」吗？"):
            return

        self._tree.delete(item)
        self._sync_to_fmeda()
        self._refresh_display()
        self._notify_change()

    # =========================================================================
    # 编辑功能（BUG修复版）
    # =========================================================================

    def _on_double_click(self, event):
        """双击单元格进入编辑模式

        可编辑列：FMD%, DC%, DC_LF%
        """
        region = self._tree.identify_region(event.x, event.y)
        if region != "cell":
            return

        row_id = self._tree.identify_row(event.y)
        column = self._tree.identify_column(event.x)

        if not row_id:
            return

        col_index = int(column.replace("#", "")) - 1

        if col_index not in EDITABLE_COLS:
            return

        self._cancel_edit()

        current_values = self._tree.item(row_id, "values")
        pct_str = str(current_values[col_index]).replace("%", "")
        try:
            edit_value = f"{float(pct_str) / PERCENT_MULTIPLIER:.4f}"
        except (ValueError, IndexError):
            edit_value = "0.00"

        bbox = self._tree.bbox(row_id, column)
        if not bbox:
            return

        x, y, width, height = bbox
        self._edit_row = row_id
        self._edit_col = col_index

        self._edit_entry = ttk.Entry(self._tree, width=15)
        self._edit_entry.place(x=x, y=y, width=width, height=height)
        self._edit_entry.insert(0, edit_value)
        self._edit_entry.select_range(0, tk.END)
        self._edit_entry.focus_set()

        self._edit_entry.bind("<Return>", lambda e: self._save_edit())
        self._edit_entry.bind("<Escape>", lambda e: self._cancel_edit())
        self._edit_entry.bind("<FocusOut>", lambda e: self._save_edit())

    def _save_edit(self):
        """保存编辑内容（BUG修复：先保存局部变量再cancel）"""
        if not self._edit_entry or not self._edit_row:
            return

        new_value = self._edit_entry.get().strip()
        # 关键修复：在_cancel_edit前保存row/col到局部变量
        saved_row = self._edit_row
        saved_col = self._edit_col
        self._cancel_edit()

        try:
            decimal_val = float(new_value)
            current_values = list(self._tree.item(saved_row, "values"))
            current_values[saved_col] = f"{decimal_val * PERCENT_MULTIPLIER:.{DECIMAL_PLACES}f}%"
            self._tree.item(saved_row, values=tuple(current_values))
            self._sync_to_fmeda()
            self._refresh_display()
            self._notify_change()
        except (ValueError, IndexError):
            pass

    def _cancel_edit(self):
        """取消编辑"""
        if self._edit_entry:
            self._edit_entry.destroy()
            self._edit_entry = None
            self._edit_row = None
            self._edit_col = None

    # =========================================================================
    # 数据同步
    # =========================================================================

    def _sync_to_fmeda(self):
        """将Treeview当前显示的数据同步回_all_fmeda

        策略：遍历Treeview行，在_all_fmeda中找到匹配的条目更新其数值，
        未在Treeview中显示的_all_fmeda条目保持不变。
        """
        # 构建Treeview中可见的(module_name, fm_name)集合
        visible_pairs = []
        prev_module = ""
        for item_id in self._tree.get_children():
            values = self._tree.item(item_id, "values")
            module_name = str(values[COL_FM_MODULE])
            if not module_name:
                module_name = prev_module
            prev_module = module_name
            fm_name = str(values[COL_FM_NAME])
            fm_pct = float(str(values[COL_FM_PCT]).replace("%", "")) / PERCENT_MULTIPLIER
            dc = float(str(values[COL_FM_DC]).replace("%", "")) / PERCENT_MULTIPLIER
            dc_lf = float(str(values[COL_FM_DC_LF]).replace("%", "")) / PERCENT_MULTIPLIER
            visible_pairs.append((module_name, fm_name, fm_pct, dc, dc_lf))

        # 更新_all_fmeda中匹配的条目
        for vp in visible_pairs:
            v_module, v_fm, v_pct, v_dc, v_dc_lf = vp
            for fm in self._all_fmeda:
                if fm.module_name == v_module and fm.fm_name == v_fm:
                    fm.fm_pct = v_pct
                    fm.dc = v_dc
                    fm.dc_lf = v_dc_lf
                    break

    def _notify_change(self):
        """通知外部数据变更"""
        if self.on_data_changed:
            self.on_data_changed()

    # =========================================================================
    # 公开接口
    # =========================================================================

    def get_fmeda_list(self) -> List[FailureMode]:
        """获取当前全量失效模式列表"""
        self._sync_to_fmeda()
        return self._all_fmeda

    def set_fmeda_list(self, fmeda_list: List[FailureMode]):
        """设置全量失效模式列表并刷新显示

        Args:
            fmeda_list: 失效模式数据列表
        """
        self._all_fmeda = fmeda_list
        self._refresh_display()

    def update_lambda_results(self):
        """更新λ_R和λ_L列的显示值"""
        for i, item_id in enumerate(self._tree.get_children()):
            if i < len(self._all_fmeda):
                fm = self._all_fmeda[i]
                current = list(self._tree.item(item_id, "values"))
                current[COL_FM_LAMBDA_R] = f"{fm.lambda_r:.{DECIMAL_PLACES}f}"
                current[COL_FM_LAMBDA_L] = f"{fm.lambda_latent:.{DECIMAL_PLACES}f}"
                self._tree.item(item_id, values=tuple(current))

    def clear(self):
        """清空面板数据"""
        self._all_fmeda.clear()
        for item in self._tree.get_children():
            self._tree.delete(item)
