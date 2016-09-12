"use strict";

const osc = require("osc"),
  express = require("express"),
  WebSocket = require("ws");

const getIPAddresses = function () {
  const os = require("os"),
    interfaces = os.networkInterfaces(),
    ipAddresses = [];

  for (let deviceName in interfaces) {
    const addresses = interfaces[deviceName];
    for (let i = 0; i < addresses.length; i++) {
      const addressInfo = addresses[i];
      if (addressInfo.family === "IPv4" && !addressInfo.internal) {
        ipAddresses.push(addressInfo.address);
      }
    }
  }

  return ipAddresses;
};

// Bind to a UDP socket to listen for incoming OSC events.
const udpPort = new osc.UDPPort({
  localAddress: "0.0.0.0",
  localPort: 57121
});

udpPort.on("ready", function () {
  const ipAddresses = getIPAddresses();
  console.log("Listening for OSC over UDP.");
  ipAddresses.forEach(function (address) {
    console.log(" Host:", address + ", Port:", udpPort.options.localPort);
  });
  console.log("To start the demo, go to http://localhost:8081 in your web browser.");
});

udpPort.open();

// Create an Express-based Web Socket server to which OSC messages will be relayed.
const appResources = __dirname + "/../client",
  app = express(),
  server = app.listen(8081),
  wss = new WebSocket.Server({
    server: server
  });

app.use("/", express.static(appResources));
app.use("/bower_components", express.static(__dirname + "/../../bower_components"));
wss.on("connection", function (socket) {
  console.log("A Web Socket connection has been established!");
  const socketPort = new osc.WebSocketPort({
    socket: socket
  });

  new osc.Relay(udpPort, socketPort, {
    raw: true
  });
});
