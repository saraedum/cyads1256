from _bcm2835 import ads_init, read_and_set_next_channel

from collections.abc import Iterable

class ADS1256:
    def __init__(self, datarate, buffered=False, gain=1):
        if buffered:
            raise NotImplementedError

        self.next_channel = -1
        self.next_timestamp = None
        self.gain = gain

        ads_init(datarate, gain)

    def read(self, channel, next_channel=None):
        if next_channel is None:
            next_channel = channel

        channel = self._encode_channel(channel)
        next_channel = self._encode_channel(next_channel)

        if channel != self.next_channel:
            if self.next_channel != -1:
                # TODO: log a warning if this is not the initial call
                raise Exception
            self._read_and_set_next_channel(channel)
        timestamp, raw = self._read_and_set_next_channel(next_channel)
        return timestamp, raw / 1677721 / self.gain

    def read_many(self, channels, next_channel=None):
        ret = []
        if next_channel is None:
            next_channel = channels[0]
        for (channel, next_channel) in zip(channels, channels[1:] + [next_channel]):
            ret.append(self.read(channel, next_channel))
        return ret

    def _read_and_set_next_channel(self, next_channel):
        from time import time
        ret = self.next_timestamp, read_and_set_next_channel(next_channel)
        self.next_channel = next_channel
        self.next_timestamp = time()
        return ret

    def _encode_channel(self, channel):
        if isinstance(channel, Iterable):
            pin1, pin2 = channel
        else:
            pin1, pin2 = channel, None

        if pin1 is None:
            pin1 = 8
        if pin2 is None:
            pin2 = 8
        return pin1<<4|pin2

    def _read_previous_channel(self):
        raise NotImplementedError
