import snowboydecoder
import sys
import signal

interrupted = False

def signal_handler(signal, frame):
    global interrupted
    interrupted = True

def interrupt_callback():
    global interrupted
    return interrupted

def detected_callback():
    #global detector #makes is slower to react
    #detector.terminate() #makes is slower to react
    sys.exit()

if len(sys.argv) == 1:
    print("Error: need to specify model name")
    print("Usage: python demo.py your.model")
    sys.exit(-1)

model = sys.argv[1]

# capture SIGINT signal, e.g., Ctrl+C
signal.signal(signal.SIGINT, signal_handler)

detector = snowboydecoder.HotwordDetector(model, sensitivity=0.5)

# main loop
detector.start(detected_callback=detected_callback,
               interrupt_check=interrupt_callback,
               sleep_time=0.03)

detector.terminate()
sys.exit(1)
