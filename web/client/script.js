/* global osc*/

const oscPort = new osc.WebSocketPort({
  url: "ws://localhost:8081" // URL to your Web Socket server.
});

oscPort.open();

oscPort.on("message", function (oscMsg) {
  console.log("An OSC message just arrived!", oscMsg);
});

