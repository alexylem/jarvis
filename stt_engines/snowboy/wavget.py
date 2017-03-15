#!/usr/bin/env python

import snowboydecoder
import snowboydetect
import pyaudio
import collections
import time
import os
import logging
import glob

logging.basicConfig()
logger = logging.getLogger("jarvis")
logger.setLevel(logging.INFO)
TOP_DIR = os.path.dirname(os.path.abspath(__file__))
RESOURCE_FILE = os.path.join(TOP_DIR, "resources","common.res")

class WavGet(object):
    """
    Snowboy decoder to save a wave.

    :param audio_gain: multiply input volume by this factor.
    :param trigger_ticks: ticks before triggering callback, tick is a sleep_time.
                   [0] ticks_silence_before_detect:
                       min silence ticks before detection
                   [1] ticks_voice_detect:
                       need this number of voice ticks
                   [3] ticks_silence_after_detect:
                       min silence ticks after detection
    """
    def __init__(self,
                 audio_gain=1,
                 trigger_ticks=[-1,-1,-1]):

        def audio_callback(in_data, frame_count, time_info, status):
            self.ring_buffer.extend(in_data)
            play_data = chr(0) * len(in_data)
            return play_data, pyaudio.paContinue

        a_model=glob.glob( os.path.join(TOP_DIR,"resources","*.[up]mdl") );
        assert len(a_model) > 0, "Need at least one model in resources to proceed"

        self.detector = snowboydetect.SnowboyDetect(
            resource_filename=RESOURCE_FILE.encode(),
            model_str=a_model[0].encode())
        self.detector.SetAudioGain( int(audio_gain) )
        """ match or not - it does not matter """
        self.detector.SetSensitivity("0.01".encode())

        self.trigger_ticks = trigger_ticks

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

    def start(self,
              output_file,
              track_mode,
              interrupt_check=lambda: False,
              sleep_time=0.03):
        """
        Start the voice detector. For every `sleep_time` second it checks the
        audio buffer.

        :param output_file: output file 'wav'. Unlink if failed.
        :param interrupt_check: a function that returns True if the main loop
                                needs to stop.
        :param float sleep_time: how much time in second every loop waits.
        :return: None
        """
        if interrupt_check():
            logger.debug("detect voice return")
            return

        if track_mode is None:
            track_mode = False

        tticks = None
        fh = None
        if track_mode == False:
            if os.path.isfile(output_file):
                os.unlink(output_file)
            tticks = self.trigger_ticks
            fh = open( output_file + ".raw", 'wb' )

        """
        to avoid 'truncate' system call.
        also the return status
        """
        fh_writen = False

        cnt = 0
        silence_before = 0
        voice = 0
        silence_after = 0
        data_onetick_before = None

        while True:
            if interrupt_check():
                logger.debug("detect voice break")
                break

            data = self.ring_buffer.get()
            if len(data) == 0:
                time.sleep(sleep_time)
                continue

            ans = self.detector.RunDetection(data)
            cnt += 1

            """ track mode """
            if track_mode:
                fmt = "%6d " % (cnt)
                if ans == -1:
                    logger.warning(fmt+"Error initializing streams or reading audio data")
                elif ans == -2:
                    logger.warning(fmt+"Silence")
                elif ans >= 0:
                    logger.warning(fmt+"Voice")
                continue

            """ store file mode """
            if ans == -1:
                logger.warning("Error initializing streams or reading audio data")

            elif ans == -2:
                """ Silence """
                if voice == 0 or silence_before < tticks[0]:
                    silence_before += 1
                elif voice >= tticks[1]:
                    """ Have enough voice to count silence_after """
                    silence_after += 1
                    if silence_after >= tticks[2]:
                        break
                """ else ignore silence """

            elif ans >= 0:
                """ Voice """
                if silence_before >= tticks[0]:
                    """ Have enough silence to count voice """
                    silence_after = 0
                    voice += 1

            if voice > 0:
                if fh_writen == False:
                    """
                    first voice activation - write also previous
                    data block to get a perfect sentence
                    """
                    fh.write( data_onetick_before )
                    fh_writen = True

                fh.write(data)

            elif fh_writen == True:
                """
                manage truncate but not in use here
                silence_before is never reset (yet)
                """
                fh.truncate(0)
                fh_writen = False

            data_onetick_before = data

        if track_mode == False:
            fh.close()

            logger.warning("Ticks status: " +
                    `silence_before` + " " +
                    `voice` + " " +
                    `silence_after` + " - return: " + `fh_writen`)

            logger.warning("Error initializing streams or reading audio data")
            logger.debug("finished.")

            if fh_writen == True:
                """ convert to wave """
                from subprocess import call
                call([
                    "sox","-r","16000","-c","1","-b","16","-e","signed-integer",
                    "-t","raw",output_file + ".raw",
                    "-t","wav",output_file])

            os.unlink(output_file + ".raw")

        return fh_writen


    def terminate(self):
        """
        Terminate audio stream. Users cannot call start() again to detect.
        :return: None
        """
        self.stream_in.stop_stream()
        self.stream_in.close()
        self.audio.terminate()
