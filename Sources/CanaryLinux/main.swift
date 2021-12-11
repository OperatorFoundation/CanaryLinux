//  MIT License
//
//  Copyright (c) 2020 Operator Foundation
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import ArgumentParser
import Foundation

import Gardener
import NetUtils
import Glibc
import Transmission

struct CanaryTest: ParsableCommand
{
    @Argument(help: "IP address for the transport server.")
    var serverIP: String
    
    @Argument(help: "Optionally set the path to the directory where Canary's required resources can be found. It is recommended that you only use this if the default directory does not work for you.")
    var resourceDirPath: String?
    
    @Option(name: NameSpecification.shortAndLong, parsing: SingleValueParsingStrategy.next, help:"Set how many times you would like Canary to run its tests.")
    var numberOfTimesToRun: Int = 1
    
    @Option(name: NameSpecification.shortAndLong, parsing: SingleValueParsingStrategy.next, help: "Optionally specify the interface name.")
    var interface: String?
    
    func validate() throws
    {
        guard numberOfTimesToRun >= 1 && numberOfTimesToRun <= 15
        else
        {
            throw ValidationError("'<runs>' must be at least 1 and no more than 15.")
        }
    }
    
    /// launch AdversaryLabClient to capture our test traffic, and run a connection test.
    ///  a csv file and song data (zipped) are saved with the test results.
    func run()
    {
        if let rPath = resourceDirPath
        {
            resourcesDirectoryPath = rPath
            print("\nUser selected resources directory: \(resourcesDirectoryPath)")
        }
        else
        {
            resourcesDirectoryPath = "\(FileManager.default.currentDirectoryPath)/Sources/Resources"
            print("\nYou did not indicate a preferred resources directory, using the default directory: \(resourcesDirectoryPath)")
        }
        
        // Make sure we have everything we need first
        guard checkSetup() else { return }
        
        var interfaceName: String
        
        if interface != nil
        {
            // Use the user provided interface name
            interfaceName = interface!
        }
        else
        {
            // Try to guess the interface, if we cannot then give up
            guard let name = guessUserInterface()
            else { return }
            
            interfaceName = name
        }
        
        for i in 1...numberOfTimesToRun
        {
            print("\n***************************\nRunning test batch \(i) of \(numberOfTimesToRun)\n***************************")
            
            for transport in allTransports
            {
                print("\n 🧪 Starting test for \(transport.name) 🧪\n")
                TestController.sharedInstance.test(name: transport.name, serverIPString: serverIP, port: transport.port, interface: interfaceName, webAddress: nil)
            }
            
            for webTest in allWebTests
            {
                print("\n 🧪 Starting web test for \(webTest.website) 🧪\n")
                TestController.sharedInstance.test(name: webTest.name, serverIPString: serverIP, port: webTest.port, interface: interfaceName, webAddress: webTest.website)
            }
            
            // This directory contains our test results.
            zipResults()
        }
        
        ShapeshifterController.sharedInstance.killAllShShifter()
        print("\nCanary tests are complete.\n")
    }
    
    func guessUserInterface() -> String?
    {
        var allInterfaces = Interface.allInterfaces()
        
        // Get interfaces sorted by name
        allInterfaces.sort(by: {
            (interfaceA, interfaceB) -> Bool in
            
            return interfaceA.name < interfaceB.name
        })
        
        print("\nYou did not indicate a preferred interface. Printing all available interfaces.")
        for interface in allInterfaces { print("\(interface.name)")}
        
        // Return the first interface that begins with the letter e
        // Note: this is just a best guess based on what we understand to be a common scenario
        // The user should use the interface flag if they have something different
        guard let bestGuess = allInterfaces.firstIndex(where: { $0.name.hasPrefix("e") })
        else
        {
            print("\nWe were unable to identify a likely interface name. Please try running the program again using the interface flag and one of the other listed interfaces.\n")
            return nil
        }
        
        print("\nWe will try using the \(allInterfaces[bestGuess].name) interface. If Canary fails to capture data, it may be because this is not the correct interface. Please try running the program again using the interface flag and one of the other listed interfaces.\n")
        
        return allInterfaces[bestGuess].name
    }
    
    func checkSetup() -> Bool
    {
        // Do we have root privileges?
        #if os(macOS)
        let euid = Darwin.geteuid()
        #else
        let euid = Glibc.geteuid()
        #endif
        
        guard euid == 0
        else
        {
            print("\nYou must run this program as root.")
            print("example: sudo ./Canary <transport server IP>")
            return false
        }
        
        // Is the transport server running
        if !allTransports.isEmpty
        {
            #if os(macOS)
            guard let _ = Transmission.Connection(host: serverIP, port: Int(string: allTransports[0].port), type: .tcp)
            else
            {
                print("Failed to connect to the transport server.")
                return false
            }
            #else
            guard let _ = TransmissionLinux.Connection(host: serverIP, port: Int(string: allTransports[0].port))
            else
            {
                print("Failed to connect to the transport server.")
                return false
            }
            #endif
        }
        
        // Does the Resources Directory Exist
        guard FileManager.default.fileExists(atPath: resourcesDirectoryPath)
        else
        {
            print("Resource directory does not exist at \(resourcesDirectoryPath).")
            return false
        }
        
        // Does it contain the files we need
        // One config for every transport being tested
        for transport in allTransports
        {
            switch transport
            {
            case obfs4:
                guard FileManager.default.fileExists(atPath: "\(resourcesDirectoryPath)/\(obfs4FilePath)")
                else
                {
                    print("obfs4 config not found at \(resourcesDirectoryPath)/\(obfs4FilePath)")
                    return false
                }
            case obfs4iatMode:
                guard FileManager.default.fileExists(atPath: "\(resourcesDirectoryPath)/\(obfs4iatFilePath)")
                else
                {
                    print("obfs4 config not found at \(resourcesDirectoryPath)/\(obfs4iatFilePath)")
                    return false
                }
            case shadowsocks:
                guard FileManager.default.fileExists(atPath:"\(resourcesDirectoryPath)/\(shSocksFilePath)")
                else
                {
                    print("Shadowsocks config not found at \(resourcesDirectoryPath)/\(shSocksFilePath)")
                    return false
                }
            case meek:
                guard FileManager.default.fileExists(atPath:"\(resourcesDirectoryPath)/\(meekOptionsPath)")
                else
                {
                    print("meek config not found at \(resourcesDirectoryPath)/\(meekOptionsPath)")
                    return false
                }
            case replicant:
                guard FileManager.default.fileExists(atPath:"\(resourcesDirectoryPath)/\(replicantFilePath)")
                else
                {
                    print("Replicant config not found at \(resourcesDirectoryPath)/\(replicantFilePath)")
                    return false
                }
            default:
                print("Tried to test a transport that has no config file. Transport name: \(transport.name)")
            }
        }
        
        // If this is Ubuntu, do we have the shapeshifter binary that we need
        guard FileManager.default.fileExists(atPath: "\(resourcesDirectoryPath)/\(shShifterResourcePath)")
        else
        {
            print("Shapeshifter binary was not found at \(resourcesDirectoryPath)/\(shShifterResourcePath). Shapeshifter Dispatcher is required in order to run Canary on Linux systems.")
            return false
        }
        
        return true
    }
}

CanaryTest.main()

signal(SIGINT)
{
    (theSignal) in

    print("Force exited the testing!! 😮")

    //Cleanup
    ShapeshifterController.sharedInstance.stopShapeshifterClient()
    //AdversaryLabController.sharedInstance.stopAdversaryLabServer()

    exit(0)
}


