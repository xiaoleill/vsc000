"""
fmeda.py — 失效模式数据模型

存储各模块的失效模式信息，包括失效占比、单点故障诊断覆盖率、
潜在故障诊断覆盖率以及计算得到的残余/潜在失效率。
"""
from dataclasses import dataclass


@dataclass
class FailureMode:
    """失效模式数据类

    每个失效模式属于某个模块。包含两个诊断覆盖率：
      - dc:    单点故障诊断覆盖率（用于SPFM计算）
      - dc_lf: 潜在故障诊断覆盖率（用于LFM计算）

    Attributes:
        module_name: 所属模块名称（如 M0, M1, ...）
        fm_name: 失效模式名称（如 FM0, FM1, ...）
        fm_pct: 该失效模式在所在模块中的占比（0~1之间的小数）
        dc: 单点故障诊断覆盖率（0~1之间的小数）
        dc_lf: 潜在故障诊断覆盖率（0~1之间的小数）
        lambda_r: 残余失效率（计算值，单位FIT），初始为0.0
        lambda_latent: 潜在失效率（计算值，单位FIT），初始为0.0
    """
    module_name: str = ""
    fm_name: str = ""
    fm_pct: float = 0.0
    dc: float = 0.0
    dc_lf: float = 0.0
    lambda_r: float = 0.0        # 计算结果：λ_R = λ_M × FMD% × (1 - DC)
    lambda_latent: float = 0.0   # 计算结果：λ_L = λ_M × FMD% × (1 - DC_LF)

    def to_dict(self) -> dict:
        """将失效模式信息转换为字典"""
        return {
            "模块(M)": self.module_name,
            "失效模式(FM)": self.fm_name,
            "失效占比(FMD%)": self.fm_pct,
            "诊断覆盖率(DC%)": self.dc,
            "潜在故障DC(DC_LF%)": self.dc_lf,
            "残余失效(λ_R/FIT)": self.lambda_r,
            "潜在失效(λ_L/FIT)": self.lambda_latent,
        }

    def __repr__(self) -> str:
        return (f"FailureMode(module={self.module_name!r}, fm={self.fm_name!r}, "
                f"fm_pct={self.fm_pct:.4f}, dc={self.dc:.4f}, dc_lf={self.dc_lf:.4f}, "
                f"lambda_r={self.lambda_r:.2f}FIT, lambda_latent={self.lambda_latent:.2f}FIT)")
