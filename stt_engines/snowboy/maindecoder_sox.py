#!/usr/bin/env python
#import snowboydecoder
import snowboydetect
#import pyaudio
import collections
import time
import os
import logging
import subprocess
import threading
import wave
import signal

logging.basicConfig()
logger = logging.getLogger("snowboy")
logger.setLevel(logging.INFO)
TOP_DIR = os.path.dirname(os.path.abspath(__file__))

RESOURCE_FILE = os.path.join(TOP_DIR, "resources/common.res")

class RingBuffer(object):
    """Ring buffer to hold audio from PortAudio"""
    def __init__(self, size = 4096):
        self._buf = collections.deque(maxlen=size)

    def extend(self, data):
        """Adds data to the end of buffer"""
        self._buf.extend(data)

    def get(self):
        """Retrieves data from the beginning of buffer and clears it"""
        tmp = bytes(bytearray(self._buf))
        self._buf.clear()
        return tmp

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
        
        model_str = ",".join(decoder_model)

        self.detector = snowboydetect.SnowboyDetect(
            resource_filename=resource.encode(), model_str=model_str.encode())
        self.audio_gain = int (audio_gain)
        #self.detector.SetAudioGain( self.audio_gain ) #537
        self.num_hotwords = self.detector.NumHotwords()
        self.trigger_ticks = trigger_ticks
        
        sensitivity_str = ",".join([str(t) for t in sensitivity])
        self.detector.SetSensitivity(sensitivity_str.encode())
        self.ring_buffer = RingBuffer( self.detector.NumChannels() * self.detector.SampleRate() * 5)
        
        # My modifications

    def record_proc(self):
        CHUNK = 2048
        RECORD_RATE = 16000
        #cmd = 'arecord -q -r %d -f S16_LE' % RECORD_RATE
        cmd = 'rec -q -r %d -c 1 -b 16 -e signed-integer --endian little -t wav - gain %d' % (RECORD_RATE, self.audio_gain) #537
        process = subprocess.Popen(cmd.split(' '), stdout = subprocess.PIPE, stderr = subprocess.PIPE)
        wav = wave.open(process.stdout, 'rb')
        while self.recording:
            data = wav.readframes(CHUNK)
            self.ring_buffer.extend(data)
        #process.terminate() # keeps mic busy for some time
        process.kill()
        
    def init_recording(self):
        """
        Start a thread for spawning arecord process and reading its stdout
        """
        self.recording = True
        self.record_thread = threading.Thread(target = self.record_proc)
        self.record_thread.start()

     #codes deleted
    
       # self.audio = pyaudio.PyAudio()
       # self.stream_in = self.audio.open(
        # input=True, output=False,
         #   format=self.audio.get_format_from_width(
          #      self.detector.BitsPerSample() / 8),
        #    channels=self.detector.NumChannels(),
         #   rate=self.detector.SampleRate(),
         #   frames_per_buffer=2048,
       #     stream_callback=audio_callback)
        logger.info ("Ticks: %s", self.trigger_ticks)

    def match_ticks(self,aticks):
        tticks = self.trigger_ticks
        """ locate the trigger position """
        silence_before = 0
        silence_after = 0
        voice_after = 0
        voice_before = 0
        kw_passed = False
        # Pattern to match is: Silence - Voice - Detection - Voice* - Silence
        for _ans in reversed(aticks):
            if kw_passed == True:
                # Before the keyword
                if _ans == -2:
                    if voice_before == 0:
                        # fail - no voice before detection?!
                        logger.info("No match - no voice before hotword")
                        return -1

                    silence_before += 1
                    if silence_before >= tticks[0]:
                        # break - complete
                        break

                elif _ans == 0:
                    # voice
                    if silence_before>0:
                        break
                    voice_before += 1

            else:
                # After the keyword
                if _ans > 0:
                    # found the keyword - switch to before keyword
                    kw_passed = True
                    continue
                if _ans == -2:
                    # silence
                    if voice_after == 0:
                        # silence after detection
                        silence_after += 1
                    else:
                        # fail - voice between silence
                        logger.info("No match - after hotword, mix of silence and voice")
                        return -1
                elif _ans == 0:
                    # voice
                    voice_after += 1

        logger.info("Ticks status: " + `silence_before` + " " +
                `voice_before` + " " +
                `voice_after` + " " + `silence_after`)
        
        # Match?
        if tticks[0]>0 and silence_before < tticks[0]:
            # will never match
            logger.warning( "No match silence_before" )
            return -1
        if tticks[1]>0 and voice_before > tticks[1]:
            # will never match
            logger.warning( "No match voice_before" )
            return -1
        if tticks[2]>0 and voice_after > tticks[2]:
            # will never match
            logger.warning( "No match voice_after" )
            return -1
        if tticks[3]>0 and silence_after < tticks[3]:
            # can still match on next tick
            logger.warning( "No match silence_after - wait next tick" )
            return 0
        # A match !
        return 1

    def start(self, detected_callback,
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
        
        self.init_recording()     #My modification
        
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
                logger.debug("detect break")
                break

            data = self.ring_buffer.get()
            if len(data) == 0:
                time.sleep(sleep_time)
                continue

            ans = self.detector.RunDetection(data)
            check_ticks = False

            # with ticks: append and keep it under 100 ticks
            if w_ticks:
                aticks.append( ans )
                if len(aticks)>100:
                    aticks.popleft()

            if ans == -1:
                logger.warning("Error initializing streams or reading audio data")

            elif ans == -2:
                # silence can trigger the callback if w_ticks and matches
                if w_ticks_onsilence == False or callback is None:
                    continue
                check_ticks = True

            elif ans > 0:
                #print "time_detected", time.time()
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
                    # Not a match
                    callback = None
                elif ret == 1:
                    #logger.warning("Callback run");
                    callback()
                    callback = None
                # ret == 0 : Not a match yet

        logger.debug("finished.")

    def terminate(self):
        """
        Terminate audio stream. Users cannot call start() again to detect.
        :return: None
        """
        #My modification
        self.recording = False
        self.record_thread.join()
        
        #old codes
        
        #self.stream_in.stop_stream()
        #self.stream_in.close()
        #self.audio.terminate()
