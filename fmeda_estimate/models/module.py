"""
module.py — 模块数据模型

存储芯片中各模块的信息，包括名称、面积占比及计算得到的失效率。
"""
from dataclasses import dataclass, field


@dataclass
class Module:
    """芯片模块数据类

    Attributes:
        name: 模块名称（如 M0, M1, ...）
        area_pct: 模块在芯片总面积中的占比（0~1之间的小数）
        lambda_m: 模块失效率（计算值，单位FIT），初始为0.0
    """
    name: str = ""
    area_pct: float = 0.0
    lambda_m: float = 0.0  # 计算结果：λ_M = λ_chip × MD%

    def to_dict(self) -> dict:
        """将模块信息转换为字典"""
        return {
            "模块(M)": self.name,
            "占比(MD%)": self.area_pct,
            "失效率(λ_M/FIT)": self.lambda_m,
        }

    def __repr__(self) -> str:
        return (f"Module(name={self.name!r}, area_pct={self.area_pct:.4f}, "
                f"lambda_m={self.lambda_m:.2f}FIT)")
