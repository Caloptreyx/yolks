#!/usr/bin/env node
// Rust console wrapper: shows the server output until WebRCON is up, then switches the console to
// WebRCON so commands typed in the panel reach the server. Derived from pterodactyl/yolks (MIT).
"use strict";

const fs = require("fs");
const { exec } = require("child_process");
const WebSocket = require("ws");

const startupCmd = process.argv.slice(2).join(" ");
if (startupCmd.length < 1) {
	console.log("Error: Please specify a startup command.");
	process.exit(1);
}

const logFile = "latest.log";
fs.writeFileSync(logFile, "");

// Rust repeats the same "Loading Prefab Bundle" percentage many times; show each one once.
const seenPercentage = new Set();
function filter(data) {
	const str = data.toString();
	if (str.startsWith("Loading Prefab Bundle ")) {
		const percentage = str.substring("Loading Prefab Bundle ".length);
		if (seenPercentage.has(percentage)) return;
		seenPercentage.add(percentage);
	}
	console.log(str);
}

console.log("Starting Rust...");

let exited = false;
const gameProcess = exec(startupCmd, { maxBuffer: Infinity });
gameProcess.stdout.on("data", filter);
gameProcess.stderr.on("data", filter);
gameProcess.on("exit", (code) => {
	exited = true;
	if (code) console.log("Main game process exited with code " + code);
	process.exit(0);
});

function stopGame() {
	if (exited) return;
	console.log("Received request to stop the process, stopping the game...");
	gameProcess.kill("SIGTERM");
}

// Container stop: forward to the game and exit once it has.
process.on("SIGTERM", stopGame);
process.on("SIGINT", stopGame);

function initialListener(data) {
	const command = data.toString().trim();
	if (command === "quit") {
		gameProcess.kill("SIGTERM");
	} else {
		console.log('Unable to run "' + command + '" due to RCON not being connected yet.');
	}
}
process.stdin.resume();
process.stdin.setEncoding("utf8");
process.stdin.on("data", initialListener);

function createPacket(command) {
	return JSON.stringify({ Identifier: -1, Message: command, Name: "WebRcon" });
}

let waiting = true;
function poll() {
	const host = process.env.RCON_IP || "localhost";
	const ws = new WebSocket("ws://" + host + ":" + process.env.RCON_PORT + "/" + process.env.RCON_PASS);

	ws.on("open", () => {
		console.log('Connected to RCON. Generating the map now. Please wait until the server status switches to "Running".');
		waiting = false;

		// Makes the server print its status, which also fixes the console output after the switch.
		ws.send(createPacket("status"));

		process.stdin.removeListener("data", initialListener);
		gameProcess.stdout.removeListener("data", filter);
		gameProcess.stderr.removeListener("data", filter);
		process.stdin.on("data", (text) => ws.send(createPacket(text)));
	});

	ws.on("message", (data) => {
		let json;
		try {
			json = JSON.parse(data.toString());
		} catch (e) {
			console.log("Error: Invalid JSON received");
			return;
		}
		if (json && typeof json.Message === "string" && json.Message.length > 0) {
			console.log(json.Message);
			fs.appendFile(logFile, "\n" + json.Message, (err) => {
				if (err) console.log("Callback error in appendFile: " + err);
			});
		}
	});

	ws.on("error", () => {
		waiting = true;
		console.log("Waiting for RCON to come up...");
		setTimeout(poll, 5000);
	});

	ws.on("close", () => {
		if (!waiting) {
			console.log("Connection to server closed.");
			exited = true;
			process.exit(0);
		}
	});
}
poll();
