"""
module_panel.py — 模块列表面板

显示芯片各模块的名称、面积占比以及计算得到的失效率λ_M。
支持双击编辑、添加(+)和删除(-)模块行。
"""
import tkinter as tk
from tkinter import ttk, messagebox
from typing import List, Callable, Optional

from config import PERCENT_MULTIPLIER, DECIMAL_PLACES
from models.module import Module


# 列索引常量
COL_M_NAME = 0    # 模块名称
COL_MD_PCT = 1    # 面积占比
COL_LAMBDA_M = 2  # 失效率 λ_M


class ModulePanel(ttk.LabelFrame):
    """模块列表面板"""

    def __init__(self, parent, on_data_changed: Optional[Callable] = None,
                 on_selection_changed: Optional[Callable] = None):
        """初始化模块面板

        Args:
            parent: 父级Tkinter容器
            on_data_changed: 数据变更回调
            on_selection_changed: 选中模块变更回调(module_name: str)
        """
        super().__init__(parent, text="模块信息 (Sheet 'Module')", padding=5)
        self.on_data_changed = on_data_changed
        self.on_selection_changed = on_selection_changed
        self._modules: List[Module] = []
        self._edit_entry = None
        self._edit_row = None
        self._edit_col = None
        self._module_counter = 0  # 自动命名计数器

        self._build_ui()

    def _build_ui(self):
        """构建Treeview、滚动条和+/-按钮"""
        # 顶部：+/- 按钮栏
        btn_frame = ttk.Frame(self)
        btn_frame.pack(fill=tk.X, padx=2, pady=(2, 0))

        self._btn_add = ttk.Button(btn_frame, text="+", width=3,
                                   command=self._on_add_module)
        self._btn_add.pack(side=tk.LEFT, padx=(0, 2))

        self._btn_del = ttk.Button(btn_frame, text="−", width=3,
                                   command=self._on_del_module)
        self._btn_del.pack(side=tk.LEFT)

        # 容器框架
        container = ttk.Frame(self)
        container.pack(fill=tk.BOTH, expand=True)

        # 定义列
        columns = ("模块(M)", "占比(MD%)", "失效率(λ_M/FIT)")
        self._tree = ttk.Treeview(
            container,
            columns=columns,
            show="headings",
            height=10,
            selectmode="browse",
        )

        self._tree.heading("模块(M)", text="模块(M)")
        self._tree.heading("占比(MD%)", text="占比(MD%)")
        self._tree.heading("失效率(λ_M/FIT)", text="失效率(λ_M/FIT)")

        self._tree.column("模块(M)", width=100, anchor="center")
        self._tree.column("占比(MD%)", width=110, anchor="center")
        self._tree.column("失效率(λ_M/FIT)", width=130, anchor="center")

        # 滚动条
        scrollbar = ttk.Scrollbar(container, orient=tk.VERTICAL,
                                  command=self._tree.yview)
        self._tree.configure(yscrollcommand=scrollbar.set)

        self._tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # 绑定事件
        self._tree.bind("<Double-1>", self._on_double_click)
        self._tree.bind("<<TreeviewSelect>>", self._on_selection)

    # =========================================================================
    # +/- 按钮操作
    # =========================================================================

    def _on_add_module(self):
        """添加新模块行"""
        self._module_counter += 1
        new_name = f"M{len(self._tree.get_children())}"
        self._tree.insert("", tk.END, values=(new_name, "0.00%", "-"))
        self._sync_to_modules()
        self._notify_change()

    def _on_del_module(self):
        """删除选中的模块行"""
        selected = self._tree.selection()
        if not selected:
            messagebox.showwarning("提示", "请先在模块列表中选择要删除的模块。")
            return

        item = selected[0]
        values = self._tree.item(item, "values")
        name = values[COL_M_NAME]

        if not messagebox.askyesno("确认删除", f"确定要删除模块「{name}」及其所有失效模式数据吗？"):
            return

        self._tree.delete(item)
        self._sync_to_modules()
        self._notify_change()

    # =========================================================================
    # 选中回调
    # =========================================================================

    def _on_selection(self, event):
        """Treeview选中行变更时触发"""
        if self.on_selection_changed:
            selected = self._tree.selection()
            if selected:
                values = self._tree.item(selected[0], "values")
                module_name = values[COL_M_NAME] if values else ""
                self.on_selection_changed(module_name)
            else:
                self.on_selection_changed("")

    def get_selected_module(self) -> Optional[str]:
        """获取当前选中的模块名称"""
        selected = self._tree.selection()
        if selected:
            values = self._tree.item(selected[0], "values")
            return str(values[COL_M_NAME]) if values else None
        return None

    # =========================================================================
    # 编辑功能（BUG修复版）
    # =========================================================================

    def _on_double_click(self, event):
        """双击单元格时进入编辑模式"""
        region = self._tree.identify_region(event.x, event.y)
        if region != "cell":
            return

        row_id = self._tree.identify_row(event.y)
        column = self._tree.identify_column(event.x)

        if not row_id:
            return

        col_index = int(column.replace("#", "")) - 1

        # λ_M 列不允许编辑
        if col_index == COL_LAMBDA_M:
            return

        self._cancel_edit()

        current_values = self._tree.item(row_id, "values")
        if col_index == COL_MD_PCT:
            try:
                pct_str = str(current_values[col_index]).replace("%", "")
                edit_value = f"{float(pct_str) / PERCENT_MULTIPLIER:.4f}"
            except (ValueError, IndexError):
                edit_value = "0.00"
        else:
            edit_value = str(current_values[col_index]) if col_index < len(current_values) else ""

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
            current_values = list(self._tree.item(saved_row, "values"))

            if saved_col == COL_M_NAME:
                current_values[saved_col] = new_value
            elif saved_col == COL_MD_PCT:
                decimal_val = float(new_value)
                current_values[saved_col] = f"{decimal_val * PERCENT_MULTIPLIER:.{DECIMAL_PLACES}f}%"

            self._tree.item(saved_row, values=tuple(current_values))
            self._sync_to_modules()
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

    def _sync_to_modules(self):
        """将Treeview中的当前数据同步到内部Module列表"""
        self._modules.clear()
        for item_id in self._tree.get_children():
            values = self._tree.item(item_id, "values")
            name = str(values[COL_M_NAME])
            pct_str = str(values[COL_MD_PCT]).replace("%", "")
            area_pct = float(pct_str) / PERCENT_MULTIPLIER if pct_str else 0.0
            lambda_m = 0.0
            try:
                lambda_m = float(values[COL_LAMBDA_M]) if values[COL_LAMBDA_M] else 0.0
            except (ValueError, IndexError):
                pass
            self._modules.append(Module(name=name, area_pct=area_pct, lambda_m=lambda_m))

    def _notify_change(self):
        """通知外部数据变更"""
        if self.on_data_changed:
            self.on_data_changed()

    # =========================================================================
    # 公开接口
    # =========================================================================

    def get_modules(self) -> List[Module]:
        """获取当前模块列表"""
        self._sync_to_modules()
        return self._modules

    def set_modules(self, modules: List[Module]):
        """设置模块列表（清空后重新填充）"""
        self._modules = modules
        for item in self._tree.get_children():
            self._tree.delete(item)
        for m in modules:
            self._tree.insert("", tk.END, values=(
                m.name,
                f"{m.area_pct * PERCENT_MULTIPLIER:.{DECIMAL_PLACES}f}%",
                f"{m.lambda_m:.{DECIMAL_PLACES}f}" if m.lambda_m else "-",
            ))

    def update_lambda_m(self):
        """更新λ_M列的显示值"""
        for i, item_id in enumerate(self._tree.get_children()):
            if i < len(self._modules):
                m = self._modules[i]
                current = list(self._tree.item(item_id, "values"))
                current[COL_LAMBDA_M] = f"{m.lambda_m:.{DECIMAL_PLACES}f}"
                self._tree.item(item_id, values=tuple(current))

    def clear(self):
        """清空面板数据"""
        self._modules.clear()
        for item in self._tree.get_children():
            self._tree.delete(item)
