# Simple Flask rest api server to make jarvis say something.
# You can edit the config inside properties.txt: jarvis_home, host, port
# Example api call : 
# curl -X POST -H "Content-Type: application/json" -d '{"message":"test pour jarvis"}' http://127.0.0.1:6543/jarvissay

from flask import Flask,json,request
import subprocess
app = Flask(__name__)

props = dict(line.strip().split('=') for line in open('properties'))

ip_host=props["ip_host"]
port_flask=int(props["port_flask"])
jarvis_home=props["jarvis_home"]


@app.route("/jarvissay", methods=['POST'])
def jarvis_say():
    if request.json:
      command="bash "+jarvis_home+"jarvis.sh -s \'"+request.json.get("message")+"\'"
      subprocess.call(command, shell=True)
    else:
        return "415 Unsupported Media Type"
    return "OK"

if __name__ == "__main__":
    app.run(host=ip_host,port=port_flask)
