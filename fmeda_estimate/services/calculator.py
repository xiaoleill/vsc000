"""
calculator.py — FMEDA计算服务

实现ISO 26262硬件架构指标的计算逻辑：

SPFM (Single Point Fault Metric) 单点故障覆盖率：
  1. λ_M[i] = λ_chip × MD%[i]
  2. λ_R[i][j] = λ_M[i] × FMD%[j] × (1 - DC[j])
  3. λ_R_sum = Σ(所有λ_R)
  4. SPFM = 1 - (λ_R_sum / λ_chip)

LFM (Latent Fault Metric) 潜在故障覆盖率：
  5. λ_L[i][j] = λ_M[i] × FMD%[j] × (1 - DC_LF[j])
  6. λ_L_sum = Σ(所有λ_L)
  7. LFM = 1 - (λ_L_sum / λ_chip)
"""
from typing import List, Tuple, Optional
from models.module import Module
from models.fmeda import FailureMode
from config import ASIL_THRESHOLDS


class Calculator:
    """FMEDA计算器

    提供模块失效率、残余/潜在失效率及SPFM/LFM指标的计算方法，
    以及ISO 26262 ASIL合规性判断。
    """

    @staticmethod
    def calc_lambda_m(lambda_chip: float, area_pct: float) -> float:
        """计算单个模块的失效率"""
        return lambda_chip * area_pct

    @staticmethod
    def calc_lambda_r(lambda_m: float, fm_pct: float, dc: float) -> float:
        """计算单个失效模式的残余失效率（用于SPFM）"""
        return lambda_m * fm_pct * (1.0 - dc)

    @staticmethod
    def calc_lambda_latent(lambda_m: float, fm_pct: float, dc_lf: float) -> float:
        """计算单个失效模式的潜在失效率（用于LFM）"""
        return lambda_m * fm_pct * (1.0 - dc_lf)

    @staticmethod
    def calc_metric(lambda_chip: float, fault_sum: float) -> float:
        """通用指标计算：1 - (fault_sum / lambda_chip)"""
        if lambda_chip == 0:
            return 0.0
        result = 1.0 - (fault_sum / lambda_chip)
        return max(0.0, min(1.0, result))  # 钳位到[0, 1]

    @staticmethod
    def check_asil_compliance(spfm: float, lfm: float, asil: str) -> dict:
        """检查SPFM和LFM是否满足指定ASIL等级要求

        Args:
            spfm: 计算得到的SPFM值（0~1）
            lfm: 计算得到的LFM值（0~1）
            asil: ASIL等级（'A'/'B'/'C'/'D'）

        Returns:
            {
                'SPFM': {'value': float, 'threshold': float|None,
                         'pass': bool|None, 'label': str},
                'LFM':  {'value': float, 'threshold': float|None,
                         'pass': bool|None, 'label': str},
            }
        """
        thresholds = ASIL_THRESHOLDS.get(asil, ASIL_THRESHOLDS['B'])

        def _check(metric_name: str, value: float) -> dict:
            threshold = thresholds.get(metric_name)
            if threshold is None:
                return {
                    'value': value,
                    'threshold': None,
                    'pass': None,  # None表示N/A（无要求）
                    'label': 'N/A',
                }
            is_pass = value >= threshold
            return {
                'value': value,
                'threshold': threshold,
                'pass': is_pass,
                'label': 'PASS' if is_pass else f'FAIL (需≥{threshold*100:.0f}%)',
            }

        return {
            'SPFM': _check('SPFM', spfm),
            'LFM': _check('LFM', lfm),
        }

    @staticmethod
    def compute_all(
        lambda_chip: float,
        modules: List[Module],
        fmeda_list: List[FailureMode]
    ) -> Tuple[float, float]:
        """执行完整的SPFM和LFM计算流程

        计算结果直接写入传入对象的对应字段中。

        Args:
            lambda_chip: 芯片总体失效率（FIT）
            modules: 模块列表（计算结果写入各Module.lambda_m）
            fmeda_list: 失效模式列表（计算结果写入各FailureMode.lambda_r/lambda_latent）

        Returns:
            (SPFM值, LFM值) 元组，取值范围0~1
        """
        # 步骤1：计算各模块失效率 λ_M = λ_chip × MD%
        for module in modules:
            module.lambda_m = Calculator.calc_lambda_m(lambda_chip, module.area_pct)

        # 构建模块名→λ_M的快速查找表
        lambda_m_map = {m.name: m.lambda_m for m in modules}

        # 步骤2：计算各失效模式的残余失效率（SPFM用）和潜在失效率（LFM用）
        lambda_r_sum = 0.0
        lambda_latent_sum = 0.0

        for fm in fmeda_list:
            lm = lambda_m_map.get(fm.module_name, 0.0)
            fm.lambda_r = Calculator.calc_lambda_r(lm, fm.fm_pct, fm.dc)
            fm.lambda_latent = Calculator.calc_lambda_latent(lm, fm.fm_pct, fm.dc_lf)
            lambda_r_sum += fm.lambda_r
            lambda_latent_sum += fm.lambda_latent

        # 步骤3：计算SPFM和LFM
        spfm = Calculator.calc_metric(lambda_chip, lambda_r_sum)
        lfm = Calculator.calc_metric(lambda_chip, lambda_latent_sum)

        return spfm, lfm
