# ERMU 验证计划对抗式审查 — 综合报告

> 审查日期：2026-07-17
> 基于：验证计划 v1.0 (120项) + DUT(ermu.v) + C059 TS Rev0.3 + HC32 RM

---

## 一、审查维度与方法

| 维度 | 审查Agent | 发现数 | 致命/严重 | 重要 | 一般/建议 |
|------|----------|--------|-----------|------|-----------|
| Gap分析 | DUT vs 文档差异 | 8项差异 | 3严重 | 5高/中 | — |
| 完整性 | 遗漏项检查 | 23项遗漏 | 5致命 | 10重要 | 8建议 |
| 正确性 | 方法/期望值校验 | 13项错误 | 4致命 | 6重要 | 3一般 |

---

## 二、致命/严重问题汇总 (MUST FIX)

### F1. DUT规模与reg model严重不匹配 【Gap分析】

当前 reg model 基于 HC32 RM (64源) 构建，DUT 实际为 **288源**。差异：

| 项目 | 当前 reg model | DUT 实际 | 影响 |
|------|---------------|----------|------|
| 错误源数 | 64 | 288 | 224个源无法通过reg model访问 |
| OM寄存器 | OM0-OM1 (64bit) | OM0-OM8 (288bit) | 224源的掩码功能无法验证 |
| ESS寄存器 | j=0-1 (2组) | j=0-8 (9组) | 7组ESS的状态读写无法进行 |
| ERC寄存器 | p=0-7 (8组) | p=0-35 (36组) | 28组ERC的响应配置无法进行 |
| PET寄存器 | j=0-1 (2组) | j=0-8 (9组) | 7组PET的伪错误触发无法进行 |

**修正：reg model 全面升级为288源架构。**

### F2. Clear Timer 行为理解错误 【正确性 #1】

- **错误理解**：CTCMP超时后自动清除EOS
- **实际行为**：Clear Timer 只是**写保护门控**——CTS=1时阻止CLR写入；CTS=0后才允许软件CLR清除EOS。**它永远不会自动清除EOS。**
- **修正**：验证方法改为"CTS=1时CLR被忽略 → CTS=0后CLR有效"

### F3. EGC 寄存器复位值错误 【正确性 #2】

- **当前值**：reg model 期望 EGC=0x0000_0000
- **实际值**：C059 TS 定义 EGC 复位值 = **0x0000_0001** (HPIE_C0 默认=1，HPI默认使能到Core0)
- **修正**：reg model 和 reg_test 期望值改为 0x1

### F4. EGC PSSRS 位域4bit→10bit 【正确性 #4 / Gap分析】

- **当前**：reg model 定义 PSSRS 仅 [19:16] 4bit (仅EOS0-3)
- **实际**：C059 TS 定义 PSSRS[25:16] **10bit**，包含 EOS0-3 + LPI0-2 + HPI + APP_RST + SYS_RST
- **修正**：reg model PSSRS 扩展为 10bit，新增 LPI/HPI/复位触发PSSR测试

### F5. WTzSE 位域 1bit→多bit独立配置 【正确性 #3】

- **当前**：reg model HPISE/LPISE 各1bit
- **实际**：HPIn[18:16] 3bit (HPI0/1/2独立)，LPIn[2:0] 3bit (LPI0/1/2独立)
- **修正**：reg model扩展为3bit字段,支持独立配置各中断通道

### F6. EMS寄存器缺失 【Gap分析】

- DUT `IMP_EMS=1`，有 `emsp_in[3:0]`、`ems_event`端口
- reg model 中 **EMSC (0x0604) 和 EMSS (0x0608) 完全缺失**
- **修正**：新增 EMSC/EMSS 寄存器定义及完整EMS测试

### F7. CCPS 位宽 16bit→8bit 【Gap分析 / 正确性 #7】

- **当前**：reg model PSS[31:16] 16bit
- **DUT参数**：`CCPS_BW=8`，实际只用 [23:16] 8bit
- **修正**：reg model PSS字段改为8bit [23:16]，高8bit reserved

### F8. PERLOCK 跨复位保持行为未验证 【完整性 #1】

- PERLOCK=1后只有Power-On Reset可解除，System/Application Reset**不能**清除
- 当前验证**完全缺失**此安全关键行为
- **修正**：新增PERLOCK在System Reset和Application Reset后的保持验证

### F9. EOUT引脚复位电平行为未验证 【完整性 #3】

- 设计规格详细定义了EOUT在不同复位类型期间/之后的电平
- POR期间Hi-Z、Application Reset期间保持、Standby Reset强制特定电平
- **修正**：新增EOUT引脚复位电平验证 + SVA互补输出断言

### F10. 互补输出SVA断言缺失 【完整性 #5】

- EOUTyM和EOUTyC永远不应同时为高或同时为低（安全关键故障）
- **修正**：Scoreboard/SVA增加实时监控断言

---

## 三、重要问题汇总 (SHOULD FIX)

| # | 问题 | 来源 | 修正方向 |
|---|------|------|---------|
| I1 | 寄存器级复位矩阵验证缺失(22寄存器×6复位类型) | 完整性#6 | 新增自动化复位矩阵测试 |
| I2 | Clear Timer新错误源重启计数器子场景不充分 | 完整性#7 | 补充CTCNT=1/中/CTCMP-1时注入新源 |
| I3 | ECpEG寄存器完整性和隔离性验证缺失 | 完整性#8 | 遍历36组ERC、邻位干扰测试 |
| I4 | 跨时钟域计数器读取密集测试缺失 | 完整性#9 | 高频读取+相位随机化+翻转边界 |
| I5 | 中断解除条件完全未定义和测试 | 完整性#10 | 新增单源/多源中断解除测试 |
| I6 | WT自触发死循环危险组合未充分验证 | 完整性#4 | 枚举LPI→LPI, HPI→HPI组合 |
| I7 | WTzC.STP字段访问类型RW→WO | 正确性#9 | reg model中STP改为WO |
| I8 | DUT N_NUM=2 vs Spec n=3差异 | 正确性#12 | 标注HPI2在当前DUT不可用 |
| I9 | CTE=0写当CTS=1时应被忽略 | 正确性#8 | 新增CTS=1时禁能CTE测试 |
| I10 | 基地址确认(0x4004_8800 vs 0x4006_2000) | 正确性#5 | 与系统集成确认后统一 |

---

## 四、优化后的验证计划架构

基于审查结果，重新规划验证层次：

### Phase 0: 基础设施修正 (阻塞项)
优先修复 reg model 使其匹配DUT实际规格，否则所有后续测试基于错误模型：

1. **reg model 全面升级为288源架构**
   - ERC: p=0~35 (36组), ESS/PET/ESSC: j=0~8 (9组)
   - OM: 每通道 j=0~8 (9组×4通道=36个OM寄存器)
   - CCPS: PSC改为8bit [23:16]
   - EGC: 复位值0x1, PSSRS 10bit [25:16]
   - WTzSE: HPIn 3bit [18:16], LPIn 3bit [2:0]
   - WTzC.STP: RW→WO
   - 新增: EMSC (0x0604), EMSS (0x0608)

2. **基地址确认为 0x4006_2000**（匹配C059 TS）

3. **EGC复位值修正为 0x0000_0001**

### Phase 1: 寄存器访问验证 (已实现基础+扩展)
| Case | 项目 | 状态 |
|------|------|------|
| ermu_reg_test | 全寄存器复位值(含EGC=0x1) | 需修正期望值 |
| ermu_reg_test | RW/RO/WO属性(含288源规模) | 需扩展规模 |
| ermu_cfglock_test | CFGLOCK/PERLOCK完整验证 | **待实现** |

### Phase 2: 错误源 + 响应控制
| Case | 项目 | 状态 |
|------|------|------|
| ermu_error_src_test | 错误源检测/清除(扩展到288源) | 已实现基础 |
| ermu_error_rsp_test | 8种ERC编码遍历 | **待实现** |
| ermu_pseudo_err_test | PET伪错误(扩展到288源) | **待实现** |
| ermu_error_mask_test | OM掩码(扩展到288源) | **待实现** |

### Phase 3: 定时器 + 输出通道
| Case | 项目 | 状态 |
|------|------|------|
| ermu_timer_test | 修正Clear/Toggle/Wait timer验证 | 已修复部分 |
| ermu_timer_test | CTS=1时禁止CLR/CTE=0 | **待新增** |
| ermu_timer_test | WT自触发死循环防护 | **待新增** |
| ermu_output_chan_test | 4通道独立/并行 | **待实现** |
| ermu_prescaler_test | CCPS预分频 | **待实现** |

### Phase 4: 中断/复位/EMS/PSSR
| Case | 项目 | 状态 |
|------|------|------|
| ermu_hpi_test | HPI路由 (N_NUM=2) | **待实现** |
| ermu_pssr_test | PSSR(含EMS功能) | **待实现** |
| ermu_reset_test | 寄存器级复位矩阵 | **待实现** |
| ermu_reset_test | PERLOCK复位保持 | **待新增** |
| ermu_reset_test | EOUT引脚复位电平 | **待新增** |

### Phase 5: 压力/并发/综合
| Case | 项目 | 状态 |
|------|------|------|
| ermu_concurrent_test | 多源并发/多通道并发 | **待实现** |
| ermu_stress_test | 随机化压力 | **待实现** |
| ermu_func_full_test | 全功能综合 | **待实现** |

### 持续监控 (SVA/Scoreboard)
- EOUTyM与EOUTyC互补断言
- 跨时钟域计数器一致性检查
- APB协议合规检查

---

## 五、统计

| 类别 | 原计划 | 新增 | 修正 | 优化后总数 |
|------|--------|------|------|-----------|
| 寄存器访问 | 18 | 2 | 3 | 20 |
| 错误源管理 | 13 | 3 | 2 | 16 |
| 错误响应控制 | 12 | 1 | 1 | 13 |
| 错误输出通道 | 16 | 3 | 1 | 19 |
| 定时器功能 | 22 | 5 | 2 | 27 |
| 中断与复位请求 | 9 | 2 | 1 | 11 |
| 紧急停止EMS | 10 | 2 | 1 | 12 |
| PSSR | 6 | 1 | 1 | 7 |
| 复位行为 | 5 | 6 | 1 | 11 |
| 压力与并发 | 7 | 1 | 0 | 8 |
| 特殊场景 | 4 | 2 | 0 | 6 |
| **合计** | **120** | **28** | **13** | **~150** |

---

## 六、优先执行顺序

```
第一步 (阻塞)：reg model 升级到288源 + EGC/PSSRS/WTzSE/CCPS位宽修正 + 基地址确认
第二步 (致命)：CFGLOCK/PERLOCK/复位行为验证
第三步 (高优)：定时器完整验证 + 中断/EMS/PSSR
第四步 (覆盖)：压力/并发/综合 + SVA断言
```
