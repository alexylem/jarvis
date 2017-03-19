#!/usr/bin/env python
import os
REC_DIR = os.path.dirname(os.path.abspath(__file__))

import sys
SB_DIR=os.path.join (REC_DIR, '../../stt_engines/snowboy')
sys.path.insert(0, SB_DIR)

import snowboydecoder
import snowboydetect

import pyaudio
import collections
import time
import logging
import glob
import struct
 
logger = logging.getLogger("recorder")
logger.setLevel(logging.INFO)
logging.basicConfig()

RESOURCE_FILE = os.path.join(SB_DIR, "resources","common.res")

""" Wav """
WAV_FORMAT_PCM = 0x0001
""" Fixed from snowboy recording """
WAV_CHANNELS    = 1
WAV_FRAMERATE   = 16000
""" 16 bits """
WAV_SAMPWIDTH   = 2

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
        
        a_model=glob.glob( os.path.join(SB_DIR,"resources","*.[up]mdl") );
        assert len(a_model) > 0, "Need at least one model in resources to proceed"
        
        self.detector = snowboydetect.SnowboyDetect(
            resource_filename=RESOURCE_FILE.encode(),
            model_str=a_model[0].encode())
        self.detector.SetAudioGain( int(audio_gain) )
        """ match or not - it does not matter """
        self.detector.SetSensitivity("0.01".encode())

        self.adata = []
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

    def _write(self, output_file):
        # Write wav header and data
        fh = open( output_file, 'wb' )
        fh.write( b'RIFF' )
        _data       = b''.join(self.adata)
        _datalength = len(_data)
        _nframes    = _datalength // (WAV_CHANNELS * WAV_SAMPWIDTH)
        fh.write(struct.pack('<L4s4sLHHLLHH4s',
            36 + _datalength, b'WAVE', b'fmt ', 16,
            WAV_FORMAT_PCM, WAV_CHANNELS, WAV_FRAMERATE,
            WAV_CHANNELS * WAV_FRAMERATE * WAV_SAMPWIDTH,
            WAV_CHANNELS * WAV_SAMPWIDTH,
            WAV_SAMPWIDTH * 8, b'data'))
        fh.write(struct.pack('<L', _datalength))
        fh.write(_data)
        fh.close()

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
        if track_mode == False:
            if os.path.isfile(output_file): # check output file already exists
                os.unlink(output_file) # delete
            tticks = self.trigger_ticks

        silence_before = 0
        voice = 0
        silence_after = 0

        while True:
            if interrupt_check():
                logger.debug("detect voice break")
                break
            
            data = self.ring_buffer.get()
            if len(data) == 0:
                time.sleep(sleep_time)
                continue
            
            ans = self.detector.RunDetection(data)

            """ track mode """
            if track_mode:
                if ans == -1:
                    logger.error("Error initializing streams or reading audio data")
                elif ans == -2:
                    sys.stdout.write('_')
                    sys.stdout.flush()
                elif ans >= 0:
                    sys.stdout.write('|')
                    sys.stdout.flush()
                continue

            """ store file mode """
            if ans == -1:
                logger.error("Error initializing streams or reading audio data")

            elif ans == -2:
                """ Silence """
                sys.stdout.write('_')
                sys.stdout.flush()
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
                sys.stdout.write('|')
                sys.stdout.flush()
                if silence_before >= tticks[0]:
                    """ Have enough silence to count voice """
                    silence_after = 0
                    voice += 1
            
            if voice > 0:
                self.adata.append( data );

            elif len(self.adata) <= 1:
                """
                Always keep track of one block before voice activation
                to get a perfect sentence
                """
                if len(self.adata)<1:
                    self.adata.append( data )
                else:
                    self.adata[0] = data

        if track_mode == False:
            logger.info("Ticks status: " +
                    `silence_before` + " " +
                    `voice` + " " +
                    `silence_after`)
            
            logger.debug("finished.")

            """ write content in wav """
            self._write( output_file )

        return

    def terminate(self):
        """
        Terminate audio stream. Users cannot call start() again to detect.
        :return: None
        """
        self.stream_in.stop_stream()
        self.stream_in.close()
        self.audio.terminate()
