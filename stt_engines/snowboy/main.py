# import librairies
import maindecoder_sox as maindecoder # snowboy decoder
import sys # exit
import signal # catch SIGINT
import argparse # program arguments
#import time # perf measurement

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
    #print "time_finished", time.time()
    sys.exit(modelid+10) # main.sh substracts 10

if __name__ == "__main__":
    # capture SIGINT signal, e.g., Ctrl+C
    signal.signal(signal.SIGINT, signal_handler)
    
    # arg parser
    parser = argparse.ArgumentParser()
    parser.add_argument('-m','--models', nargs='+', help='<Required> list of models', required=True)
    parser.add_argument('-s','--sensitivity', help='sensitivity', default='0.4')
    parser.add_argument('-g','--gain', help='audio gain', type=int, default=0)
    parser.add_argument('-t', '--ticks', help='check ticks', action='store_true')
    args = parser.parse_args()
    
    # retrieve arguments
    #models = sys.argv[2:]
    models=args.models
    nbmodel = len(models)
    sensitivity = args.sensitivity
    
    # if len(sys.argv) < 3:
    #     print("Error: need to specify the sensitivity and at least one model")
    #     print("Usage: python main.py 0.5 resources/model1.pmdl resources/model2.pmdl [...]")
    #     sys.exit(-1)
    
    # build array of callbacks by model
    callbacks = []
    for i in range(1,nbmodel+1):
        callbacks.append(lambda i=i: detected_callback(i))
        
    # build array of sensitivities by model
    sensitivities = [sensitivity]*nbmodel
    
    # build array of ticks
    if args.ticks:
        # a tick is the sleep time of snowboy
        # [ min silence ticks before detection, 
        #   max voice ticks before detection,      - "jarvis" itself
        #   max voice ticks after detection        - "ss" of "Jarvisss"
        #   min silence ticks after detection ]    - -1 for immediate reaction
        ticks = [ 2, 20, 5, -1 ] #TODO get from jarvis as user settings
    else:
        ticks = [ -1, -1, -1, -1 ]
        
    # initiatlize decoder
    detector = maindecoder.JarvisHotwordDetector(
        models,
        sensitivity=sensitivities,
        audio_gain=args.gain,
        trigger_ticks=ticks)

    # run decoder
    detector.start(detected_callback=callbacks,
                   interrupt_check=interrupt_callback,
                   sleep_time=0.03)
    
    # should not reach here, issue occured
    detector.terminate()
    sys.exit(-1)
