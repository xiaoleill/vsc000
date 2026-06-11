"""
validator.py — 输入校验服务

在计算前对用户输入的数据进行合法性校验，确保满足ISO 26262 FMEDA分析的约束条件。

校验规则：
  1. 占比和诊断覆盖率（DC, DC_LF）的值必须介于0~1之间
  2. 所有模块的面积占比之和必须等于1
  3. 输入的模块数目必须与实际导入的模块个数一致
"""
from typing import List, Tuple
from config import SUM_TOLERANCE, RANGE_MIN, RANGE_MAX


class Validator:
    """输入校验器"""

    @staticmethod
    def validate_range(value: float, label: str = "") -> Tuple[bool, str]:
        """校验单个值是否在[0, 1]范围内"""
        if value < RANGE_MIN or value > RANGE_MAX:
            msg = f"「{label}」的值 {value:.4f} 超出允许范围 [{RANGE_MIN}, {RANGE_MAX}]"
            return False, msg
        return True, ""

    @staticmethod
    def validate_all_percentages(
        modules: List,
        fmeda_list: List
    ) -> Tuple[bool, List[str]]:
        """校验所有占比和DC值是否在[0, 1]范围内

        校验对象包括：
        - 各模块的面积占比 (area_pct)
        - 各失效模式的失效占比 (fm_pct)
        - 各失效模式的单点故障诊断覆盖率 (dc)
        - 各失效模式的潜在故障诊断覆盖率 (dc_lf)
        """
        errors = []

        for m in modules:
            ok, err = Validator.validate_range(m.area_pct, f"模块{m.name}占比(MD%)")
            if not ok:
                errors.append(err)

        for fm in fmeda_list:
            ok, err = Validator.validate_range(
                fm.fm_pct, f"模块{fm.module_name}的{fm.fm_name}失效占比(FMD%)"
            )
            if not ok:
                errors.append(err)

            ok, err = Validator.validate_range(
                fm.dc, f"模块{fm.module_name}的{fm.fm_name}诊断覆盖率(DC%)"
            )
            if not ok:
                errors.append(err)

            # 新增：校验潜在故障DC
            ok, err = Validator.validate_range(
                fm.dc_lf, f"模块{fm.module_name}的{fm.fm_name}潜在故障DC(DC_LF%)"
            )
            if not ok:
                errors.append(err)

        return len(errors) == 0, errors

    @staticmethod
    def validate_module_sum(modules: List) -> Tuple[bool, str]:
        """校验所有模块面积占比之和是否等于1"""
        total = sum(m.area_pct for m in modules)
        if abs(total - 1.0) > SUM_TOLERANCE:
            msg = (
                f"所有模块占比之和必须等于1.00，当前总和为 {total:.4f}，"
                f"偏差为 {abs(total - 1.0):.6f}"
            )
            return False, msg
        return True, ""

    @staticmethod
    def validate_module_count(expected_count: int, modules: List) -> Tuple[bool, str]:
        """校验模块数目是否与实际导入的模块个数一致"""
        actual_count = len(modules)
        if expected_count != actual_count:
            msg = (
                f"模块数目不一致：Info中声明的模块数 M_num={expected_count}，"
                f"但实际导入的模块个数为 {actual_count}"
            )
            return False, msg
        return True, ""

    @staticmethod
    def validate_all(
        expected_m_num: int,
        modules: List,
        fmeda_list: List
    ) -> Tuple[bool, List[str]]:
        """执行全部校验，汇总所有错误信息"""
        all_errors = []

        ok, errors = Validator.validate_all_percentages(modules, fmeda_list)
        if not ok:
            all_errors.extend(errors)

        ok, err = Validator.validate_module_sum(modules)
        if not ok:
            all_errors.append(err)

        ok, err = Validator.validate_module_count(expected_m_num, modules)
        if not ok:
            all_errors.append(err)

        return len(all_errors) == 0, all_errors
