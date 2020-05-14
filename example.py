from ads1256 import ADS1256
from time import time

def measure_switching_performance(seconds=10):
    r"""
    2.5 104% = 25 / 24
    5 95% = 50 / 52
    10 97% = 100 / 102
    15 98% = 150 / 152
    25 98% = 250 / 253
    30 98% = 300 / 304
    50 98% = 500 / 509
    60 99% = 600 / 602
    100 98% = 1000 / 1010
    500 95% = 5000 / 5222
    1000 92% = 10000 / 10794
    2000 88% = 20000 / 22707
    3750 83% = 37500 / 45172
    7500 77% = 75000 / 96600
    15000 73% = 150000 / 204023
    30000 70% = 300000 / 424505
    """
    theory = { 30000 : 4374,
               15000 : 3817,
                7500 : 3043,
                3750 : 2165,
                2000 : 1438,
                1000 :  837,
                 500 :  456,
                 100 :   98,
                  60 :   59,
                  50 :   50,
                  30 :   30,
                  25 :   25,
                  15 :   15,
                  10 :   10,
                   5 :    5,
                 2.5 :  2.5 }
 
    for rate in sorted(theory.keys()):
        ads = ADS1256(rate)
        start = time()
        count = int(theory[rate]*seconds)
        for i in range(count//2):
            ads.read([0, 1])
        end = time()
        bound = theory[rate]*(end-start)
        print(rate, "%2d%% = %d / %d"%((count / bound)*100, count, bound))

# measure_switching_performance(2)

def histogram(pin1, pin2, rate=100, samples=200):
    ads = ADS1256(rate, gain=1)
    channel = ads.compute_channel(pin1, pin2)
    ret = []
    for i in range(samples):
        # print(ads.read([pin]))
        ret.append(ads.read([channel])[0][1])
    return ret

print(histogram(4, 3))
