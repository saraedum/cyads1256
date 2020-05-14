from ads1256 import ADS1256
import csv
import sys

def do_measurement(pins, rate=50, gain=1): #rate set to 100
    ads = ADS1256(rate, gain=gain)
    channels = []
    writer = csv.writer(sys.stdout)
    for pin in pins:
        channels.append(ads.compute_channel(pin[0], pin[1]))
    
    while True:
        rawdata = []
        readchannels = ads.read(channels)
        rawdata.append(readchannels[0][0])
        for data in readchannels:
            rawdata.append(data[1])
        writer.writerow(rawdata)
        sys.stdout.flush()

do_measurement(pins = [(1, 2), (4, 3), (5, 3)])
