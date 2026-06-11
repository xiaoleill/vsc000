# FMEDA评估系统 — ISO 26262 SPFM计算工具

基于ISO 26262功能安全标准的硬件架构指标SPFM（单点故障覆盖率）评估工具。

## 功能特性

- **Excel数据导入**：支持从3个Sheet（Info/Module/FMEDA）导入芯片FMEDA数据
- **在线编辑**：支持在GUI中直接修改模块占比、失效模式占比和诊断覆盖率
- **自动计算**：一键计算各模块失效率λ_M、残余失效率λ_R及SPFM指标
- **数据校验**：自动校验输入值范围、模块占比总和等约束
- **结果导出**：将计算结果导出至Excel，包含Result Sheet
- **可视化切换**：支持独立显示/隐藏模块面板和FMEDA面板

## 目录结构

```
fmeda_estimate/
├── main.py                    # 程序入口
├── config.py                  # 全局常量配置
├── models/                    # 数据模型层
│   ├── chip_info.py           # 芯片信息模型
│   ├── module.py              # 模块模型
│   └── fmeda.py               # 失效模式模型
├── services/                  # 业务逻辑层
│   ├── excel_io.py            # Excel读写服务
│   ├── calculator.py          # FMEDA计算引擎
│   └── validator.py           # 输入校验器
├── views/                     # GUI视图层
│   ├── main_window.py         # 主窗口
│   ├── info_panel.py          # 芯片信息面板
│   ├── module_panel.py        # 模块列表面板
│   ├── fmeda_panel.py         # FMEDA表面板
│   └── result_panel.py        # SPFM结果面板
├── test_data/                 # 测试数据
│   ├── example_input.xlsx     # 示例Excel输入
│   ├── example_input.html     # 测试数据HTML预览
│   └── generate_example.py    # 示例数据生成脚本
└── README.md
```

## 环境依赖

- Python 3.7+
- openpyxl（Excel读写）
- tkinter（Python标准库，通常已内置）

## 安装与运行

### 1. 安装依赖

```bash
pip install openpyxl
```

### 2. 启动应用

```bash
cd fmeda_estimate
python main.py
```

### 3. 使用流程

1. 点击「📥 导入Excel」选择输入文件（可使用 `test_data/example_input.xlsx` 测试）
2. 检查导入的数据，可按需双击单元格修改数值
3. 点击「🔢 计算 SPFM」执行校验和计算
4. 查看各模块失效率λ_M、残余失效率λ_R和SPFM结果
5. 点击「📤 导出Excel」保存结果

## 计算原理

根据ISO 26262-5:2018 Annex D，SPFM计算公式如下：

```
λ_M[i]      = λ_chip × MD%[i]
λ_R[i][j]   = λ_M[i] × FMD%[j] × (1 - DC[j])
λ_R_sum     = Σ λ_R[i][j]
SPFM        = 1 - (λ_R_sum / λ_chip)
```

其中：
- λ_chip：芯片总体失效率（FIT）
- MD%：模块面积占比
- FMD%：失效模式在模块内的占比
- DC：诊断覆盖率
- SPFM取值范围：0~1，ISO 26262要求 ASIL B ≥ 90%, ASIL C/D ≥ 97%/99%

## 输入Excel格式

### Sheet 'Info'（芯片信息）

| 参数 | 值 |
|------|-----|
| 项目名称(project) | SAFETY_CHIP_X1 |
| 芯片总面积(chip_area) | 99999.00 |
| 总体失效率(λ_chip/FIT) | 100.00 |
| 模块数目(M_num) | 3 |

### Sheet 'Module'（模块列表）

| 模块(M) | 占比(MD%) |
|---------|-----------|
| M0_CPU_Core | 0.40 |
| M1_Memory | 0.35 |
| M2_Peripheral | 0.25 |

### Sheet 'FMEDA'（失效模式，含合并单元格）

| 模块(M) | 失效模式(FM) | 失效占比(FMD%) | 诊断覆盖率(DC%) |
|---------|-------------|---------------|----------------|
| M0_CPU_Core | FM0_ALU_Parity_Error | 0.35 | 0.95 |
| (合并) | FM1_Register_Soft_Error | 0.40 | 0.90 |
| (合并) | FM2_Control_Unit_SEU | 0.25 | 0.85 |
| M1_Memory | FM0_SRAM_Multi_Bit_Upset | 0.55 | 0.92 |
| (合并) | FM1_ECC_Decoder_Failure | 0.45 | 0.88 |

## 许可证

MIT License
