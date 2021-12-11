//
//  TransportConnectionTest.swift
//  Canary
//
//  Created by Mafalda on 2/2/21.
//

import Foundation

import Chord
import Transport

#if (os(macOS) || os(iOS) || os(watchOS) || os(tvOS))
import Network
#else
import NetworkLinux
#endif

class TransportConnectionTest
{
    var transportConnection: Connection
    var canaryString: String?
    var readBuffer = Data()
    
    init(transportConnection: Connection, canaryString: String?)
    {
        self.transportConnection = transportConnection
        self.canaryString = canaryString
    }
    
    func send(completionHandler: @escaping (NWError?) -> Void)
    {
        transportConnection.send(content: Data(string: httpRequestString), contentContext: .defaultMessage, isComplete: true, completion: NWConnection.SendCompletion.contentProcessed(completionHandler))
    }
    
    func read(completionHandler: @escaping (Data?) -> Void)
    {
        transportConnection.receive(minimumIncompleteLength: 1, maximumLength: 1500)
        {
            (maybeData,_,_, maybeError) in
            
            if let error = maybeError
            {
                print("Error reading data for transport connection: \(error)")
                completionHandler(self.readBuffer)
                return
            }
            
            if let data = maybeData
            {
                print("Canary received data \(data). Appending to the buffer.")
                self.readBuffer.append(data)
                
                
                if self.readBuffer.string.contains("Yeah!\n")
                {
                    completionHandler(self.readBuffer)
                    return
                }
                
                self.read(completionHandler: completionHandler)
            }
            else
            {
                completionHandler(self.readBuffer)
                return
            }
        }
    }
    
    func run() -> Bool
    {
        print("📣 Running transport connection test.")
        
        let maybeError = Synchronizer.sync(self.send)
        if let error = maybeError
        {
            print("Error sending http request for TransportConnectionTest: \(error)")
            return false
        }
        
        let response = Synchronizer.sync(read)
        guard let responseData = response
            else
        {
            print("🚫 We did not receive a response 🚫")
                return false
        }
        
        guard let responseString = String(data: responseData, encoding: .utf8)
        else
        {
            print("We could not convert the response data into a string \(responseData)")
            return false
        }
        
        print("Response data as string: \n\(responseString)")
        let substrings = responseString.components(separatedBy: "\r\n\r\n")
        
        guard substrings.count > 1
        else
        {
            print("🚫 We received a response with only headers: \(responseString) 🚫")
            return false
        }
        
        let payloadString = String(substrings[1])
                
        //Control Data
        if canaryString != nil
        {
            if canaryString == payloadString
            {
                print("💕 🐥 It works! 🐥 💕")
                return true
            }
            else
            {
                print("\n🖤  We connected but the data did not match. 🖤")
                print("Here's what we got back instead: \(payloadString)")
                
                return false
            }
        }
        
        return true

    }
}
