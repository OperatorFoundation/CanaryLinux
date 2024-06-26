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
import Logging

import Canary
import NetUtils

#if os(Linux)
import Glibc
#endif

struct CanaryTest: ParsableCommand
{
    @Argument(help: "The path to the directory where the transport specific config files can be found.")
    var resourceDirPath: String
    
    @Option(name: .shortAndLong, parsing: .next, help: "Optionally specify the directory where the results should be saved.")
    var savePath: String?
    
    @Option(name: NameSpecification.shortAndLong, parsing: SingleValueParsingStrategy.next, help:"Set how many times you would like Canary to run its tests.")
    var rounds: Int = 1
    
    @Option(name: NameSpecification.shortAndLong, parsing: SingleValueParsingStrategy.next, help: "Optionally specify the interface name.")
    var interface: String?
    
    @Flag(name: NameSpecification.shortAndLong, help: "When this flag is set Canary will also run web tests. By default web tests are not run.")
    var webTests: Bool = false
    
    func validate() throws
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
            throw ValidationError("You must run this program as root: sudo ./Canary <transport server IP>")
        }
        
        // Does the Resources Directory Exist
        guard FileManager.default.fileExists(atPath: resourceDirPath)
        else
        {
            throw ValidationError("Resource directory does not exist at \(resourceDirPath).")
        }
        
        guard rounds >= 1 && rounds <= 15
        else
        {
            throw ValidationError("'<rounds>' must be at least 1 and no more than 15.")
        }
        
    }
    
    /// launch AdversaryLabClient to capture our test traffic, and run a connection test.
    ///  a csv file and song data (zipped) are saved with the test results.
    func run()
    {
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
        
        let canary = Canary(configPath: resourceDirPath, savePath: savePath, logger: uiLog, timesToRun: rounds, interface: interfaceName, debugPrints: false, runWebTests: webTests)
        
        print("Canary is preparing to run tests...")
        
        Task 
        {
            await canary.runTest()
            print("Canary testing is complete!")
        }
    }
    
    func guessUserInterface() -> String?
    {
        let allInterfaces = Interface.allInterfaces()
        
        // Remove any interfaces named "lo" these are not useful to us
        var filteredInterfaces = allInterfaces.filter({ $0.name != "lo"})
        
        guard !filteredInterfaces.isEmpty
        else
        {
            print("\n ‼️We were unable to identify a likely interface name. Please try running the program again using the correct interface name for your system.\n")
            
            return nil
        }
        
        // Get interfaces sorted by name
        filteredInterfaces.sort(by: {
            (interfaceA, interfaceB) -> Bool in
            
            return interfaceA.name < interfaceB.name
        })
        
        print("\nYou did not indicate a preferred interface. Printing all available interfaces.")
        for interface in filteredInterfaces { print("\(interface.name)")}
        
        var bestGuessIndex: Int
        
        // Return the first interface that begins with the letter e
        // Note: this is just a best guess based on what we understand to be a common scenario
        // The user should use the interface flag if they have something different
        if let eNameIndex = filteredInterfaces.firstIndex(where: { $0.name.hasPrefix("e") })
        {
            bestGuessIndex = eNameIndex
        }
        else
        {
            bestGuessIndex = 0
        }

        print("\n⚠️ We will try using the \(filteredInterfaces[bestGuessIndex].name) interface. If Canary fails to capture data, it may be because this is not the correct interface. Please try running the program again using the interface flag and one of the other listed interfaces.\n")
        
        return filteredInterfaces[bestGuessIndex].name
    }
}

CanaryTest.main()

signal(SIGINT)
{
    (theSignal) in

    print("Force exited the testing!! 😮")

    exit(0)
}


