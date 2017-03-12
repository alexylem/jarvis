#!/usr/bin/env python

import snowboydecoder
import snowboydetect
import pyaudio
import collections
import time
import os
import logging

logging.basicConfig()
logger = logging.getLogger("snowboy")
logger.setLevel(logging.INFO)
TOP_DIR = os.path.dirname(os.path.abspath(__file__))

RESOURCE_FILE = os.path.join(TOP_DIR, "resources/common.res")

class JarvisHotwordDetector(object):
    """
    Snowboy decoder to detect whether a keyword specified by `decoder_model`
    exists in a microphone input stream.

    :param decoder_model: decoder model file path, a string or a list of strings
    :param resource: resource file path.
    :param sensitivity: decoder sensitivity, a float of a list of floats.
                              The bigger the value, the more senstive the
                              decoder. If an empty list is provided, then the
                              default sensitivity in the model will be used.
    :param audio_gain: multiply input volume by this factor.
    :param trigger_ticks: ticks before triggering callback, tick is a sleep_time.
                   [0] ticks_silence_before_detect:
                       min silence ticks before detection
                   [1] param ticks_voice_before_detect:
                       max voice ticks before detection
                   [2] ticks_voice_after_detect:
                       max voice ticks after detection
                   [3] ticks_silence_after_detect:
                       min silence ticks after detection
    """
    def __init__(self, decoder_model,
                 resource=RESOURCE_FILE,
                 sensitivity=[],
                 audio_gain=1,
                 trigger_ticks=[-1,-1,-1,-1]):

        def audio_callback(in_data, frame_count, time_info, status):
            self.ring_buffer.extend(in_data)
            play_data = chr(0) * len(in_data)
            return play_data, pyaudio.paContinue

        tm = type(decoder_model)
        ts = type(sensitivity)
        tt = type(trigger_ticks)
        if tm is not list:
            decoder_model = [decoder_model]
        if ts is not list:
            sensitivity = [sensitivity]
        if tt is not list:
            trigger_ticks = [-1,-1,-1,-1]
        model_str = ",".join(decoder_model)

        self.detector = snowboydetect.SnowboyDetect(
            resource_filename=resource.encode(), model_str=model_str.encode())
        self.detector.SetAudioGain(audio_gain)
        self.num_hotwords = self.detector.NumHotwords()
        self.trigger_ticks = trigger_ticks

        if len(decoder_model) > 1 and len(sensitivity) == 1:
            sensitivity = sensitivity*self.num_hotwords
        if len(sensitivity) != 0:
            assert self.num_hotwords == len(sensitivity), \
                "number of hotwords in decoder_model (%d) and sensitivity " \
                "(%d) does not match" % (self.num_hotwords, len(sensitivity))
        sensitivity_str = ",".join([str(t) for t in sensitivity])
        if len(sensitivity) != 0:
            self.detector.SetSensitivity(sensitivity_str.encode())

        self.ring_buffer = snowboydecoder.RingBuffer(
            self.detector.NumChannels() * self.detector.SampleRate() * 5)
        self.audio = pyaudio.PyAudio()
        self.stream_in = self.audio.open(
            input=True, output=False,
            format=self.audio.get_format_from_width(
                self.detector.BitsPerSample() / 8),
            channels=self.detector.NumChannels(),
            rate=self.detector.SampleRate(),
            frames_per_buffer=2048,
            stream_callback=audio_callback)
        
        logger.info ("Ticks: %s", self.trigger_ticks)

    def match_ticks(self,aticks):
        tticks = self.trigger_ticks
        """ locate the trigger position """
        silence_before = 0
        silence_after = 0
        voice_after = 0
        voice_before = 0
        kw_passed = False
        """ Pattern to match is: Silence - Voice - Detection - Voice* - Silence """
        for _ans in reversed(aticks):
            if kw_passed == True:
                """ Before the keyword """
                if _ans == -2:
                    if voice_before == 0:
                        """ fail - no voice before detection?! """
                        logger.info("No match - no voice before hotword")
                        return -1

                    silence_before += 1
                    if silence_before >= tticks[0]:
                        """ break - complete """
                        break

                elif _ans == 0:
                    """ voice """
                    if silence_before>0:
                        break
                    voice_before += 1

            else:
                """ After the keyword """
                if _ans > 0:
                    """ found the keyword - switch to before keyword """
                    kw_passed = True
                    continue
                if _ans == -2:
                    """ silence """
                    if voice_after == 0:
                        """ silence after detection """
                        silence_after += 1
                    else:
                        """ fail - voice between silence """
                        logger.info("No match - after hotword, mix of silence and voice")
                        return -1
                elif _ans == 0:
                    """ voice """
                    voice_after += 1

        logger.info("Ticks status: " + `silence_before` + " " +
                `voice_before` + " " +
                `voice_after` + " " + `silence_after`)

        """ Match? """
        if tticks[0]>0 and silence_before < tticks[0]:
            """ will never match """
            logger.warning( "No match silence_before" )
            return -1
        if tticks[1]>0 and voice_before > tticks[1]:
            """ will never match """
            logger.warning( "No match voice_before" )
            return -1
        if tticks[2]>0 and voice_after > tticks[2]:
            """ will never match """
            logger.warning( "No match voice_after" )
            return -1
        if tticks[3]>0 and silence_after < tticks[3]:
            """ can still match on next tick """
            logger.warning( "No match silence_after - wait next tick" )
            return 0
        """ A match ! """
        return 1

    def start(self, detected_callback=snowboydecoder.play_audio_file,
              interrupt_check=lambda: False,
              sleep_time=0.03):
        """
        Start the voice detector. For every `sleep_time` second it checks the
        audio buffer for triggering keywords. If detected, then call
        corresponding function in `detected_callback`, which can be a single
        function (single model) or a list of callback functions (multiple
        models). Every loop it also calls `interrupt_check` -- if it returns
        True, then breaks from the loop and return.

        :param detected_callback: a function or list of functions. The number of
                                  items must match the number of models in
                                  `decoder_model`.
        :param interrupt_check: a function that returns True if the main loop
                                needs to stop.
        :param float sleep_time: how much time in second every loop waits.
        :return: None
        """
        if interrupt_check():
            logger.debug("detect voice return")
            return

        tc = type(detected_callback)
        if tc is not list:
            detected_callback = [detected_callback]
        if len(detected_callback) == 1 and self.num_hotwords > 1:
            detected_callback *= self.num_hotwords

        assert self.num_hotwords == len(detected_callback), \
            "Error: hotwords in your models (%d) do not match the number of " \
            "callbacks (%d)" % (self.num_hotwords, len(detected_callback))

        logger.debug("detecting...")

        """ with ticks compute """
        tticks = self.trigger_ticks
        aticks = collections.deque()
        w_ticks = False
        w_ticks_onsilence = False
        if tticks[2] != -1 or tticks[3] != -1:
            w_ticks_onsilence = True
        if tticks[0] != -1 or tticks[1] != -1 or w_ticks_onsilence != False:
            w_ticks = True
        callback = None

        while True:
            if interrupt_check():
                logger.debug("detect voice break")
                break

            data = self.ring_buffer.get()
            if len(data) == 0:
                time.sleep(sleep_time)
                continue

            ans = self.detector.RunDetection(data)
            check_ticks = False

            """ with ticks: append and keep it under 100 ticks """
            if w_ticks:
                aticks.append( ans )
                if len(aticks)>100:
                    aticks.popleft()

            if ans == -1:
                logger.warning("Error initializing streams or reading audio data")

            elif ans == -2:
                """ silence can trigger the callback if w_ticks and matches """
                if w_ticks_onsilence == False or callback is None:
                    continue
                check_ticks = True

            elif ans > 0:
                message = "Keyword " + str(ans) + " detected at time: "
                message += time.strftime("%Y-%m-%d %H:%M:%S",
                                         time.localtime(time.time()))
                logger.info(message)
                callback = detected_callback[ans-1]
                if callback is not None:
                    if w_ticks == False:
                        callback()
                    elif w_ticks_onsilence == False:
                        check_ticks = True

            if check_ticks:
                ret = self.match_ticks( aticks )
                if ret == -1:
                    """ Not a match """
                    callback = None
                elif ret == 1:
                    #logger.warning("Callback run");
                    callback()
                    callback = None
                """ ret == 0 : Not a match yet """

        logger.debug("finished.")

    def terminate(self):
        """
        Terminate audio stream. Users cannot call start() again to detect.
        :return: None
        """
        self.stream_in.stop_stream()
        self.stream_in.close()
        self.audio.terminate()
