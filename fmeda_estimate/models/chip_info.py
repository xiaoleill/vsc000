"""
chip_info.py — 芯片信息数据模型

存储芯片级别的基本信息，包括项目名称、面积、总体失效率、ASIL等级等。
"""
from dataclasses import dataclass
from config import (
    DEFAULT_PROJECT, DEFAULT_CHIP_AREA, DEFAULT_LAMBDA_CHIP,
    DEFAULT_M_NUM, DEFAULT_ASIL
)


@dataclass
class ChipInfo:
    """芯片基本信息数据类

    Attributes:
        project: 芯片/项目名称（字符串）
        chip_area: 芯片总面积（实数，无单位）
        lambda_chip: 芯片总体失效率（实数，单位FIT）
        m_num: 芯片所包含的模块数目（整数）
        asil: ASIL等级（'A'/'B'/'C'/'D'）
    """
    project: str = DEFAULT_PROJECT
    chip_area: float = DEFAULT_CHIP_AREA
    lambda_chip: float = DEFAULT_LAMBDA_CHIP
    m_num: int = DEFAULT_M_NUM
    asil: str = DEFAULT_ASIL

    def to_dict(self) -> dict:
        """将芯片信息转换为字典，便于Excel导出"""
        return {
            "项目名称(project)": self.project,
            "芯片总面积(chip_area)": self.chip_area,
            "总体失效率(λ_chip/FIT)": self.lambda_chip,
            "模块数目(M_num)": self.m_num,
            "ASIL等级": self.asil,
        }

    def __repr__(self) -> str:
        return (f"ChipInfo(project={self.project!r}, chip_area={self.chip_area:.2f}, "
                f"lambda_chip={self.lambda_chip:.2f}FIT, m_num={self.m_num}, "
                f"ASIL={self.asil})")
