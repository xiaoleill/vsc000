# ERMU 验证环境优化 — 分步执行规划

> 基于: 验证计划v2.0 (169项) + 对抗式审查综合报告 (F1-F10, I1-I9)
> 原则: 第一性原理 — 从最底层基础设施开始，每步通过lint后进入下一步

---

## 依赖层次分析

```
Layer 0 (基础): reg model — 所有测试通过reg model访问DUT
Layer 1 (依赖): 已有test修正 — reg_test, timer_test基于修正后的model
Layer 2 (扩展): 新test case — 基于正确的reg model + 正确的测试方法
Layer 3 (质量): 断言/监控 — Scoreboard SVA, 跨域检查
```

---

## Step 1: Reg Model 字段修正 (F3, F4, F5, F7, I7)

**文件**: `ERMU_UT/reg/ermu_reg_pkg.sv`

**修改项**:
| # | 寄存器/字段 | 当前值 | 修正为 | 对应审查 |
|---|-----------|--------|--------|---------|
| 1.1 | EGC 复位值 | 0x0000_0000 | 0x0000_0001 | F3 |
| 1.2 | EGC PSSRS | [19:16] 4bit | [25:16] 10bit | F4 |
| 1.3 | EGC HPIE_C[1:0] 默认值 | 2'b00 | 2'b01 (HPIE_C0=1) | F3 |
| 1.4 | WTzSE HPIn | [16] 1bit | [18:16] 3bit | F5 |
| 1.5 | WTzSE LPIn | [0] 1bit | [2:0] 3bit | F5 |
| 1.6 | CCPS PSS | [31:16] 16bit | [23:16] 8bit, [31:24] Reserved RO | F7 |
| 1.7 | WTzC STP | RW | WO (读回0) | I7 |

**验证标准**: `make lint` 通过，然后 `make compile` 通过

---

## Step 2: Reg Model 规模扩展 (F1, F6)

**文件**: `ERMU_UT/reg/ermu_reg_pkg.sv`

**修改项**:
| # | 修改 | 说明 |
|---|------|------|
| 2.1 | EOyOM0/OM1 → EOyOM array [0:8] | 每通道9组OM寄存器 (288bit掩码)，偏移 y*0x80 + j*0x04 + 0x40 |
| 2.2 | 新增 EMSC (0x0604) | EMSEN/EMSMOD/EMSPOL/EMSEL/EMSCLR/EMSSET |
| 2.3 | 新增 EMSS (0x0608) | EMSS[0] RO |

**验证标准**: `make lint` + `make compile` 通过

---

## Step 3: Reg Test 期望值修正

**文件**: `ERMU_UT/test/ermu_reg_test.sv`

**修改项**:
| # | 修改 | 说明 |
|---|------|------|
| 3.1 | EGC 复位值期望 | 0x0 → 0x0000_0001 |
| 3.2 | 扩展OM寄存器复位值检查 | OM0~OM8 per channel (4ch × 9 = 36个OM寄存器) |
| 3.3 | 扩展ERC复位值遍历 | p=0~35 (当前已遍历0~35? 确认) |
| 3.4 | 新增EMSC/EMSS复位值检查 | EMSC=0x0, EMSS=0x0 |

**验证标准**: `make lint` + `make compile` 通过

---

## Step 4: Timer Test 行为修正 (F2)

**文件**: `ERMU_UT/test/ermu_timer_test.sv`

**修改项**:
| # | 修改 | 说明 |
|---|------|------|
| 4.1 | Clear Timer 期待结果修正 | "自动清除EOS" → "CTS=0后软件CLR清除" |
| 4.2 | 新增 CTS=1时CLR被忽略子测试 | 验证写保护门控行为 |
| 4.3 | 新增 CTS=1时写CTE=0被忽略 | 验证计数期间禁止禁能 |
| 4.4 | WTzSE 多路独立启动测试 | 使用3bit LPIn/HPIn分别使能 |

**验证标准**: `make lint` + `make compile` 通过, `make timer` 期望PASS

---

## Step 5: CFGLOCK/PERLOCK Test (新增) (F8, I1)

**文件**: `ERMU_UT/test/ermu_cfglock_test.sv` (新建)

**验证项**:
| # | 验证 |
|---|------|
| 5.1 | CFGLOCK默认锁定 → 受保护寄存器写被忽略 |
| 5.2 | KEY=0xBC 解锁 → 受保护寄存器可写 |
| 5.3 | KEY≠0xBC 重新锁定 |
| 5.4 | PERLOCK KEY=0xFF 永久锁定 |
| 5.5 | PERLOCK=1 后CFGLOCK解锁无效 |
| 5.6 | System Reset后PERLOCK保持=1 |
| 5.7 | Power-On Reset后PERLOCK恢复=0 |
| 5.8 | EOyC.CLR和WTzC.STP不受CFGLOCK保护 |

**文件改动**: 
- 新建 `ermu_cfglock_test.sv`
- 修改 `ermu_test_pkg.sv` 添加 `include`

**验证标准**: `make lint` + `make compile` + `make cfglock` 期望PASS

---

## Step 6: Error Response Test (新增)

**文件**: `ERMU_UT/test/ermu_error_rsp_test.sv` (新建)

**验证项**: 8种ERC编码遍历 (NA/RSV/LPI0-LPI2/HPI/APP_RST/SYS_RST)

**验证标准**: `make lint` + `make compile` 通过

---

## Step 7: 剩余 Test Case 实现 (Phase 2-5)

按验证计划优先级依次实现:
- HPI test
- Output channel test  
- EMS/PSSR test
- Error mask test (288源)
- Pseudo error test (288源)
- Prescaler test
- Reset test (寄存器级矩阵)
- Concurrent test
- Stress test
- Full function test

每一步均需: `make lint` + `make compile` 通过

---

## Step 目视检查汇总

| Step | 文件 | 改动量 | 依赖 |
|------|------|--------|------|
| 1 | reg_pkg.sv | ~7处字段修正 | — |
| 2 | reg_pkg.sv | ~新增OM数组+EMSC/EMSS | Step 1 |
| 3 | reg_test.sv | ~修正期望值+扩展范围 | Step 1,2 |
| 4 | timer_test.sv | ~修正验证方法 | Step 1 |
| 5 | cfglock_test.sv (新) + test_pkg.sv | 新文件 | Step 1,2 |
| 6 | error_rsp_test.sv (新) + test_pkg.sv | 新文件 | Step 1,2 |
| 7 | N个test文件 | 逐一新增 | Step 1-6 |

---

## 确认事项

请确认：
1. **Base Address**: 保持 `0x4004_8800` 还是改为 C059 TS 的 `0x4006_2000`？
2. **DUT 实际寄存器地址空间**: WT offset stride 是 0x0020 还是 0x0080？EOyOM 组数确认 9 组？
3. **Step 1-2 是否合并执行**（都在同一个 reg_pkg.sv 文件，合并更高效）？
4. **是否从 Step 1 立即开始**？
