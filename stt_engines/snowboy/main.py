import maindecoder_sox as maindecoder
import sys
import signal

# Demo code for listening two hotwords at the same time

# hide alsa errors # not anymore needed with sox?
# from ctypes import *
# ERROR_HANDLER_FUNC = CFUNCTYPE(None, c_char_p, c_int, c_char_p, c_int, c_char_p)
# def py_error_handler(filename, line, function, err, fmt):
#     pass
# c_error_handler = ERROR_HANDLER_FUNC(py_error_handler)
# try:
#     asound = cdll.LoadLibrary('libasound.so.2')
#     asound.snd_lib_error_set_handler(c_error_handler)
# except Exception as e:
#     pass

interrupted = False

def signal_handler(signal, frame):
    global interrupted
    interrupted = True

def interrupt_callback():
    global interrupted
    return interrupted

def detected_callback(modelid):
    global detector
    detector.terminate() #makes it 0.1 sec slower to react
    sys.exit(modelid+10) # main.sh substracts 10

if len(sys.argv) < 3:
    print("Error: need to specify the sensitivity and at least one model")
    print("Usage: python main.py 0.5 resources/model1.pmdl resources/model2.pmdl [...]")
    sys.exit(-1)

# capture SIGINT signal, e.g., Ctrl+C
signal.signal(signal.SIGINT, signal_handler)

models = sys.argv[2:]
nbmodel = len(models)
callbacks = []
for i in range(1,nbmodel+1):
    callbacks.append(lambda i=i: detected_callback(i))

sensitivity = sys.argv[1]
sensitivities = [sensitivity]*nbmodel
# Trigger ticks:
#   a tick is the sleep time of snowboy - argument of start()
#   [0] ticks_silence_before_detect:
#       min silence ticks before detection
#   [1] param ticks_voice_before_detect:
#       max voice ticks before detection
#   [2] ticks_voice_after_detect:
#       max voice ticks after detection
#   [3] ticks_silence_after_detect:
#       min silence ticks after detection
trigger_ticks = [ 2, 20, 5, -1 ]

detector = maindecoder.JarvisHotwordDetector(
    models,
    sensitivity=sensitivities,
    trigger_ticks=trigger_ticks)

# main loop
# make sure you have the same numbers of callbacks and models
detector.start(detected_callback=callbacks,
               interrupt_check=interrupt_callback,
               sleep_time=0.03)

detector.terminate()
sys.exit(-1)
