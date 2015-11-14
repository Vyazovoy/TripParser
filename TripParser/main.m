//
//  main.m
//  TripParser
//
//  Created by Andrey Vyazovoy on 14/11/15.
//  Copyright © 2015 Andrew Vyazovoy.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

@import Foundation;

#import "parser.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSURL *applicationURL = [NSURL fileURLWithFileSystemRepresentation:argv[0]
                                                               isDirectory:NO
                                                             relativeToURL:nil];
        
        if (!applicationURL) {
            printf("Executable path is malformed\n");
            
            return 1;
        }
        NSURL *fileURL = [NSURL fileURLWithFileSystemRepresentation:argv[1]
                                                        isDirectory:NO
                                                      relativeToURL:applicationURL];
        
        if (!fileURL) {
            printf("File path is malformed\n");
            
            return 1;
        }
        FindCharactersFromCStringInFileWithURL("OneTwoTrip", fileURL);
    }
    
    return 0;
}
