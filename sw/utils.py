import numpy as np


def coef2LUT(
    coef: np.ndarray, LUT_depth: int = 4096, max_input: int = 16384
) -> np.ndarray:
    """
    Convert MP coefficients to LUT content.
    1. ``max_input`` is for the value which represent 1 in the fixed point scheme.

    """
