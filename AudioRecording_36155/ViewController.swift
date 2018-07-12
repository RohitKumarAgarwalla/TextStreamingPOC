//
//  ViewController.swift
//  AudioRecording_36155
//
//  Created by Rohit Kumar Agarwalla on 7/4/18.
//  Copyright © 2018 com.rohit. All rights reserved.
//

import UIKit
import Starscream
//import SocketRocket

class ViewController: UIViewController {

	var audioFile: NGAudioRecord = NGAudioRecord()
	var socket: WebSocket?
	var audioData: Data = Data()
	@IBOutlet weak var recordButton: UIButton!
	@IBOutlet weak var playBackButton: UIButton!
	@IBOutlet weak var convertButton: UIButton!
	
//	var socketRocket: SRWebSocket?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		audioFile.recordDelegate = self
		
//		let filePath = Bundle.main.path(forResource: "2016121200000003", ofType: "ogg")
//		do {
//			self.audioData = ExtAudioFileOpenURL(URL(string: filePath!)! as NSURL, nil)
//			print("Audio data is \(self.audioData)")
//		} catch {
//			print("error is \(error)")
//		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	@IBAction func didClickOnPlaybackButton(_ sender: Any) {
		if !audioFile.playingState.playing {
			audioFile.startPlayback()
		} else {
			Swift.print("This is getting called")
			audioFile.stopPlayback()
		}
	}
	
	@IBAction func didClickOnRecordButton(_ sender: Any) {
		if !audioFile.playingState.playing {
			if !audioFile.recordState.recording {
				Swift.print("Started recording")
				audioFile.startRecording()
				recordButton.titleLabel?.text = "Stop"
				recordButton.setTitle("Stop", for: UIControlState.normal)
			} else {
				Swift.print("Stop recording")
				audioFile.stopRecording()
				recordButton.titleLabel?.text = "Record"
				recordButton.setTitle("Record", for: UIControlState.normal)
				Swift.print("Audio data is \(self.audioData)")
			}
		} else {
			Swift.print("Playing the audio. Please try after stopping")
		}
	}
	
	var start = [
		"apiVersion": "1.0",
		"method": "STARTDICTATION",
		"params": [
			"id": "ragarwalla@nextgen.com",
//			"authorization": "Entrada1!",
			"apikey": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJOZXh0R2VuIChUZW5hbnQpIiwiaXNzIjoiblZvcSIsIm9yZ2hhc2giOiJUbVY0ZEVkbGJsOVVaVzVoYm5SZlh6SXpNRGM2YjNKbllXNXBlbUYwYVc5dU9qTSIsImV4cCI6MTU2Mjc5MjI1NiwiaWF0IjoxNTMxMjU2MjU2fQ.V2PbjLIKV6EQ0uwXn9p1rTbUMSDTnri9cWIivuefbuIfU1ewIE0k8Ix1cjR--dhGqN9NBxGp7QoIUzZfnaepuFCIaPEwWrpPa0GHDGqNJ5lbGeRks7h4-Eh5VvOniZ2unznMZOasYftHavWEJ7y9117Iaq64Ft5Us0NdIxVLRuNiEl1KGUVp_pEVfBAQhSx7GxAFXnbTn6UKxNYnexlfSqo8jHLigkm5QpBxhb9s8Ryhe55ny94a3HiO6TnlspMVhFyUexu49NMEW6cIH4xZ_Jn5oLZMpaYomlwvMxooJ58COFjgbJa1isrTQFcmTSARCcrQIKteZ8BOWR77cb5gfQ",
			"audioFormat": [
				"encoding": "pcm-16khz",
				"sampleRate": 16000
			],
			"snsContext": [
				"dictationContextText": "",
				"selectionOffset": 0,
				"selectionEndIndex": 0
			]
		]
	] as [String : Any]
	
	var done = [
		"apiVersion" : "1.0",
		"method" : "AUDIODONE"
	]
	
	@IBAction func didClickOnConvert(_ sender: Any) {
		do {
			convertButton.setTitle("Connecting...", for: UIControlState.normal)
			let startJSON = try JSONSerialization.data(withJSONObject: start, options: .prettyPrinted)
			
			
			if let socketURL = URL(string: "wss://eval.nvoq.com:443/wsapi/v2/dictation/topics/general_medicine") {
				var socketURLRequest = URLRequest(url: socketURL)
				socketURLRequest.setValue("eval.nvoq.com", forHTTPHeaderField: "Host")
				
				socket = WebSocket(request: socketURLRequest)
				socket?.onConnect = {
					self.convertButton.setTitle("Connected", for: UIControlState.normal)
					if let sString = String(data: startJSON, encoding: String.Encoding.utf8) {
						self.socket?.write(string: sString)
					}
				}
				
				socket?.onDisconnect = { (err) -> Void in
					self.convertButton.setTitle("Convert", for: UIControlState.normal)
					Swift.print("Error reported while disconnecting is \(err)")
				}
			}
			socket?.delegate = self
			socket?.connect()

			
			/*
			if let nVoqURL = URL(string: "wss://eval.nvoq.com:443/wsapi/v2/dictation/topics/general_medicine") {
				let nVoqURLRequest = URLRequest(url: nVoqURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60.0)
				socketRocket = SRWebSocket(urlRequest: nVoqURLRequest)
				Swift.print("Socket rocket is \(socketRocket)")
				socketRocket?.open()
				socketRocket?.delegate = self
			}
			*/
		} catch {
			
		}
		
	}
}


extension ViewController: WebSocketDelegate {
	func websocketDidConnect(socket: WebSocketClient) {
		print("Socket did connect")
	}
	
	func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
		print("Socket did disconnect \(String(describing: error))")
	}
	
	func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
		print("Socket did receive data")
	}
	
	func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
		print("Socket did receive message \(text)")
	}
	
}

extension ViewController: NGAudioRecordDelegate {
	func didRecord(_ data: Data!) {
		self.audioData.append(data)
		self.socket?.write(data: data)
		
		do {
			try self.audioData.write(to: getNewFileName())
		} catch {
			Swift.print("error is \(error)")
		}
		
	}
	
	func getNewFileName() -> URL {
		let documentDirectoryPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
		let docDirectory = documentDirectoryPath[0]
		
		return docDirectory.appendingPathComponent("/recording111.aif")
	}
}

/*
extension ViewController: SRWebSocketDelegate {
	func webSocketDidOpen(_ webSocket: SRWebSocket!) {
		Swift.print("Web socket did open")
	}
	
	func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
		Swift.print("web socket did receive message")
	}
	
	func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
		Swift.print("web socket did fail with error \(error)")
	}
	
	func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
		Swift.print("Web socket is closed due to code: \(code) and reason \(reason) and wasClean \(wasClean)")
	}
}
*/
