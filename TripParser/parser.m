//
//  parser.m
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

#include "parser.h"

typedef struct symbol_s Symbol;
struct symbol_s {
    Symbol *previousSymbol;
    Symbol *nextSymbol;
    char character;
    NSInteger m;
    NSInteger n;
};

static BOOL LinkedSymbolArrayForString(const char *string, Symbol **array, size_t *size) {
    if (!string || strlen(string) == 0 || !array || *array || !size) return NO;
    size_t stringLength = strlen(string);
    Symbol *symbols = calloc(strlen(string), sizeof(Symbol));
    
    for (NSInteger i = 0; i < stringLength; i++) {
        char character = string[i];
        Symbol *currentSymbol = &symbols[i];
        currentSymbol->character = character;
        
        if (i > 0) {
            Symbol *previousSymbol = &symbols[i - 1];
            currentSymbol->previousSymbol = previousSymbol;
            previousSymbol->nextSymbol = currentSymbol;
        }
    }
    *array = symbols;
    *size = stringLength;
    return YES;
}

static BOOL HandleHittedListItemAndRearrangeListForCharacter(char character, NSInteger m, NSInteger n, Symbol **listHead) {
    if (!listHead) return NO;
    Symbol *currentSymbol = *listHead;
    
    while (currentSymbol) {
        if (tolower(currentSymbol->character) == tolower(character)) {
            if (currentSymbol->previousSymbol) {
                currentSymbol->previousSymbol->nextSymbol = currentSymbol->nextSymbol;
            } else {
                *listHead = currentSymbol->nextSymbol;
            }
            
            if (currentSymbol->nextSymbol) {
                currentSymbol->nextSymbol->previousSymbol = currentSymbol->previousSymbol;
            }
            currentSymbol->character = character;
            currentSymbol->m = m;
            currentSymbol->n = n;
            
            return YES;
        }
        currentSymbol = currentSymbol->nextSymbol;
    }
    
    return NO;
}

static BOOL ParseCStringForMatrixDimensions(const char *string, NSInteger *m, NSInteger *n) {
    if (string == NULL || m == NULL || n == NULL) return NO;
    NSString *dimensionsString = [NSString stringWithCString:string encoding:NSUTF8StringEncoding];
    NSCharacterSet *whitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];
    NSArray<NSString *> *matrixDimensions = [[dimensionsString stringByTrimmingCharactersInSet:whitespaceCharacterSet] componentsSeparatedByCharactersInSet:whitespaceCharacterSet];
    
    if (matrixDimensions.count < 2) return NO;
    NSInteger rowCount = matrixDimensions[0].integerValue;
    NSInteger columnCount = matrixDimensions[1].integerValue;
    
    if (rowCount == 0 || columnCount == 0 || rowCount > 10000 || columnCount > 10000) return NO;
    *m = rowCount;
    *n = columnCount;
    
    return YES;
}

FOUNDATION_EXTERN void FindCharactersFromCStringInFileWithURL(const char *string, NSURL *fileURL) {
    if (!string || strlen(string) == 0) {
        NSLog(@"Inspectabe string is malformed");
        
        return;
    }
    NSError * __autoreleasing error;
    
    if (!fileURL || ![fileURL checkResourceIsReachableAndReturnError:&error]) {
        NSLog(@"File unreachable.\n%@", error ?: @"File URL is nil.");
        
        return;
    }
    dispatch_queue_t queue = dispatch_queue_create("com.vyazovoy.TripParser.serial", DISPATCH_QUEUE_SERIAL);
    NSInteger __block channelErrorCode = 0;
    dispatch_io_t readChannel = dispatch_io_create_with_path(DISPATCH_IO_STREAM, fileURL.fileSystemRepresentation, O_RDONLY, 0, queue, ^(int error) {
        channelErrorCode = error;
        
        if (error != 0) {
            NSLog(@"Read file channel was closed with error: %d", error);
        }
    });
    
    if (!readChannel) {
        NSLog(@"Read file channel creation failed");
        
        return;
    }
    NSInteger firstLineMaxLenght = 12; //10000 10000
    char * __block firstLineCString = calloc(firstLineMaxLenght, sizeof(char));
    
    if (!firstLineCString) {
        NSLog(@"Memory allocation problem");
        
        return;
    }
    size_t symbolCount = 0;
    Symbol *symbols = NULL;
    
    if (!LinkedSymbolArrayForString(string, &symbols, &symbolCount)) {
        NSLog(@"String conversion to linked array failed.");
        
        return;
    }
    Symbol * __block listHead = symbols;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    BOOL __block firstLineParsed = NO;
    NSInteger __block m = 0;
    NSInteger __block n = 0;
    NSInteger __block i = 0;
    NSInteger __block j = 0;
    
    dispatch_io_read(readChannel, 0, SIZE_MAX, queue, ^(bool done, dispatch_data_t data, int error) {
        if (error != 0) {
            channelErrorCode = error;
        }
        BOOL failed = !dispatch_data_apply(data, ^bool(dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
            for (NSInteger enumerateCounter = 0; enumerateCounter < size; enumerateCounter++) {
                char character = ((const char *)buffer)[enumerateCounter];
                
                if (firstLineParsed) {
                    if (character != '\n') {
                        if (j < n && HandleHittedListItemAndRearrangeListForCharacter(character, i, j, &listHead) && !listHead) {
                            return NO;
                        }
                        j++;
                    } else {
                        i++;
                        
                        if (i >= m || j < n) return NO;
                        j = 0;
                    }
                } else {
                    if (character != '\n') {
                        if (i < firstLineMaxLenght) {
                            firstLineCString[i] = character;
                        }
                        i++;
                    } else if (ParseCStringForMatrixDimensions(firstLineCString, &m, &n)) {
                        i = 0;
                        firstLineParsed = YES;
                        free(firstLineCString);
                    } else {
                        return NO;
                    }
                }
            }
            
            return YES;
        });
        
        if (done || failed) {
            dispatch_semaphore_signal(semaphore);
        }
    });
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    dispatch_io_close(readChannel, DISPATCH_IO_STOP);
    
    if (!listHead) {
        for (NSInteger i = 0 ; i < symbolCount; i++) {
            Symbol *currentSymbol = &symbols[i];
            printf("%c - (%ld, %ld);\n", currentSymbol->character, (long)currentSymbol->m, (long)currentSymbol->n);
        }
    } else {
        printf("Impossible\n");
    }
    free(symbols);
}
