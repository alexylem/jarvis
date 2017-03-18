import wavget
import sys
import signal

# hide alsa errors
from ctypes import *
ERROR_HANDLER_FUNC = CFUNCTYPE(None, c_char_p, c_int, c_char_p, c_int, c_char_p)
def py_error_handler(filename, line, function, err, fmt):
    pass
c_error_handler = ERROR_HANDLER_FUNC(py_error_handler)
try:
    asound = cdll.LoadLibrary('libasound.so.2')
    asound.snd_lib_error_set_handler(c_error_handler)
except Exception as e:
    pass

interrupted = False

def signal_handler(signal, frame):
    global interrupted
    interrupted = True

def interrupt_callback():
    global interrupted
    return interrupted

if len(sys.argv) != 3:
    print("Error: need to match")
    print("Usage: python wave.py <audio_gain> <file>")
    sys.exit(-1)

# capture SIGINT signal, e.g., Ctrl+C
signal.signal(signal.SIGINT, signal_handler)

audio_gain = sys.argv[1]
output_file = sys.argv[2]
track_mode = False


if int(audio_gain) <= 0:
    """ mandatory """
    audio_gain = 1

if output_file == "track":
    output_file = "/dev/null"
    track_mode = True

# Trigger ticks:
#   a tick is the sleep time of snowboy (default: 0.03)
#   [0] ticks_silence_before_voice:
#       min silence ticks before detection
#   [1] ticks_voice
#       min voice ticks to be valid
#   [2] ticks_silence_after_voice:
#       min silence ticks after detection
trigger_ticks = [ 2, 6, 3 ]

detector = wavget.WavGet(
        audio_gain=audio_gain,
        trigger_ticks=trigger_ticks )

# main loop
# make sure you have the same numbers of callbacks and models
detector.start(interrupt_check=interrupt_callback,
        output_file=output_file,
        track_mode=track_mode,
        sleep_time=0.03)

detector.terminate()
sys.exit(0)
