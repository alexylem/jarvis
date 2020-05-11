import pyaudio
import pvporcupine
import sys
import struct

if __name__ == "__main__":
    detected = False
    porcupine = None
    pa = None
    audio_stream = None
    if len(sys.argv) < 2:
        # Print to stdout, as stderr is silenced in non-verbose mode
        print("ERROR: No trigger specified")
        sys.exit(1)
    elif sys.argv[1] not in pvporcupine.KEYWORDS:
        print("ERROR: Porcupine is not trained for the specified trigger\n\
        Available triggers are: " + str(pvporcupine.KEYWORDS))
        sys.exit(1)
    trigger = sys.argv[1]
    try:
        porcupine = pvporcupine.create(keywords=[trigger])
        pa = pyaudio.PyAudio()
        audio_stream = pa.open(
            rate=porcupine.sample_rate,
            channels=1,
            format=pyaudio.paInt16,
            input=True,
            frames_per_buffer=porcupine.frame_length)
        while not detected:
            pcm = audio_stream.read(porcupine.frame_length)
            pcm = struct.unpack_from("h" * porcupine.frame_length, pcm)
            detected = porcupine.process(pcm)

    except KeyboardInterrupt:
        print("Keyboard interrupt. Stopping Porcupine...", file=sys.stderr)
    except Exception as e:
        print(e, file=sys.stderr)
        print("An error occurred. Stopping Porcupine...", file=sys.stderr)
        sys.exit(1)

    finally:
        if porcupine is not None:
            porcupine.delete()
        if audio_stream is not None:
            audio_stream.close()
        if pa is not None:
            pa.terminate()

    if detected:
        sys.exit(11)  # Exit code 11 means that the keyword was detected
    else:
        # Exit code 0 means that the script was stopped without an error occurring or the keyword being detected
        sys.exit(0)
