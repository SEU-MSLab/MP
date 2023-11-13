'''
Copyright 2023 Microwave System Lab or its affiliates. All Rights Reserved.
File: mp.py
Authors:
Zhe Li, 904016301@qq.com

Description:
The memory polynomial model extraction and evaluation functions. 

Revision history:
Version   Date        Author      Changes
1.0    2023-11-10    Zhe Li      initial version
'''
from matplotlib import legend
import numpy as np
import scipy.io
import matplotlib.pyplot as plt
import argparse


def MP_e(x_target: np.ndarray, y_target: np.ndarray, M, K, N)->np.ndarray:
    """
    This is the coefficient extraction file based on MP DPD
    designed by Qianyun Lu, Feb. 2, 2018, qianyun.lu@seu.edu.cn
    Refer to following paper for more information: 
    [1] https://digital-library.theiet.org/content/journals/10.1049/el_20010940
    [2] http://ieeexplore.ieee.org/document/6353238/

    Args:
        x_target: the PA input signal,
        y_target: the PA output signal
        M: memory depth
        K: non-linearity order,
        N: number of samples for extraction

    Returns:
        coef: the extracted coefficients
    """
    x_target = np.ravel(x_target) # Change from 2D to 1D array
    y_target = np.ravel(y_target) # Change from 2D to 1D array
    x_target = np.concatenate([x_target[-M:], x_target[0:N-1], x_target[N:N+M-1]])
    y_target = y_target[0:N]
    X = np.empty((N, (M+1)*(K+1)), dtype='complex_')
    for m in range(M+1):
        for k in range(K+1):
            X[:, m+k] = x_target[M-m:M-m+N] * np.power(np.abs(x_target[M-m:M-m+N]), k)
    X[np.isnan(X)] = 0 # Remove NaN
    XH = np.conjugate(X.T)
    coef = np.linalg.pinv(XH.dot(X) + 0.000001*np.eye(X.shape[1])).dot(XH).dot(y_target.T)
    return coef

def MP_v(x_target: np.ndarray, coef: np.ndarray, M, K)->np.ndarray:
    """
    This is the coefficient evaluation file based on MP DPD
    designed by Qianyun Lu, Feb. 2, 2018, qianyun.lu@seu.edu.cn
    
    Args:
        x_target: the PA input signal
        coef: the extracted coefficients
        M: memory depth
        K: non-linearity order,
    
    Returns:
        y: the calculated model output
    """
    N = len(x_target)
    x_target = np.ravel(x_target) # Change from 2D to 1D array
    x_target = np.concatenate([x_target[-M:], x_target, x_target[0:M]])
    X = np.empty((N, (K+1)*(M+1)), dtype='complex_')
    for m in range(M+1):
        for k in range(K+1):
            X[:, m+k] = x_target[M-m:M-m+N] * np.power(np.abs(x_target[M-m:M-m+N]), k)

    y = X.dot(coef)
    return y

if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument('-f', "--file", type=str, default='PA_data.mat', help='input file name')
    parser.add_argument('-M', type=int, default=3, help='memory depth')
    parser.add_argument('-K', type=int, default=7, help='non-linearity order')

    args=parser.parse_args()

    PA_in = np.ravel(scipy.io.loadmat(args.file)['xorg'])
    PA_out = np.ravel(scipy.io.loadmat(args.file)['yorg'])

    coef = MP_e(PA_in, PA_out, args.M, args.K, 16384)
    PA_exp = MP_v(PA_in, coef, args.M, args.K)

    plt.plot(np.abs(PA_in[0:1000]), label="PA original input")
    plt.plot(np.abs(PA_out[0:1000]), label="PA original output")
    plt.plot(np.abs(PA_exp[0:1000]), label="PA expected output")
    plt.legend()
    plt.show()
