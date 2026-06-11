"""
models — FMEDA评估系统的数据模型层

提供芯片信息、模块、失效模式等核心数据结构。
"""
from .chip_info import ChipInfo
from .module import Module
from .fmeda import FailureMode

__all__ = ["ChipInfo", "Module", "FailureMode"]
