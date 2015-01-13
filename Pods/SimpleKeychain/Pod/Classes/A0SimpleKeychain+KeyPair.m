//  A0SimpleKeychain+KeyPair.m
//
// Copyright (c) 2014 Auth0 (http://auth0.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "A0SimpleKeychain+KeyPair.h"

@implementation A0SimpleKeychain (KeyPair)

- (BOOL)generateRSAKeyPairWithLength:(A0SimpleKeychainRSAKeySize)keyLength
                        publicKeyTag:(NSString *)publicKeyTag
                       privateKeyTag:(NSString *)privateKeyTag {
    NSAssert(publicKeyTag.length > 0 && privateKeyTag.length > 0, @"Both key tags should be non-empty!");

    NSMutableDictionary *pairAttr = [@{
                                       (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
                                       (__bridge id)kSecAttrKeySizeInBits: @(keyLength),
                                       } mutableCopy];
    NSDictionary *privateAttr = @{
                                  (__bridge id)kSecAttrIsPermanent: @YES,
                                  (__bridge id)kSecAttrApplicationTag: [privateKeyTag dataUsingEncoding:NSUTF8StringEncoding],
                                  };
    NSDictionary *publicAttr = @{
                                 (__bridge id)kSecAttrIsPermanent: @YES,
                                 (__bridge id)kSecAttrApplicationTag: [publicKeyTag dataUsingEncoding:NSUTF8StringEncoding],
                                 };
    pairAttr[(__bridge id)kSecPrivateKeyAttrs] = privateAttr;
    pairAttr[(__bridge id)kSecPublicKeyAttrs] = publicAttr;

    SecKeyRef publicKeyRef;
    SecKeyRef privateKeyRef;

    OSStatus status = SecKeyGeneratePair((__bridge CFDictionaryRef)pairAttr, &publicKeyRef, &privateKeyRef);

    CFRelease(publicKeyRef);
    CFRelease(privateKeyRef);

    return status == errSecSuccess;
}

- (NSData *)dataForRSAKeyWithTag:(NSString *)keyTag {
    NSAssert(keyTag.length > 0, @"key tag should be non-empty!");

    NSDictionary *publicKeyQuery = @{
                                     (__bridge id)kSecClass: (__bridge id)kSecClassKey,
                                     (__bridge id)kSecAttrApplicationTag: [keyTag dataUsingEncoding:NSUTF8StringEncoding],
                                     (__bridge id)kSecAttrType: (__bridge id)kSecAttrKeyTypeRSA,
                                     (__bridge id)kSecReturnData: @YES,
                                     };

    CFTypeRef dataRef;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)publicKeyQuery, &dataRef);

    if (status != errSecSuccess) {
        return nil;
    }

    NSData *data = [NSData dataWithData:(__bridge NSData *)dataRef];
    if (dataRef) {
        CFRelease(dataRef);
    }
    return data;
}

- (BOOL)hasRSAKeyWithTag:(NSString *)keyTag {
    NSAssert(keyTag.length > 0, @"key tag should be non-empty!");

    NSDictionary *publicKeyQuery = @{
                                     (__bridge id)kSecClass: (__bridge id)kSecClassKey,
                                     (__bridge id)kSecAttrApplicationTag: [keyTag dataUsingEncoding:NSUTF8StringEncoding],
                                     (__bridge id)kSecAttrType: (__bridge id)kSecAttrKeyTypeRSA,
                                     (__bridge id)kSecReturnData: @NO,
                                     };

    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)publicKeyQuery, NULL);
    return status == errSecSuccess;
}


- (BOOL)deleteRSAKeyWithTag:(NSString *)keyTag {
    NSAssert(keyTag.length > 0, @"key tag should be non-empty!");
    NSDictionary *deleteKeyQuery = @{
                                     (__bridge id)kSecClass: (__bridge id)kSecClassKey,
                                     (__bridge id)kSecAttrApplicationTag: [keyTag dataUsingEncoding:NSUTF8StringEncoding],
                                     (__bridge id)kSecAttrType: (__bridge id)kSecAttrKeyTypeRSA,
                                     };

    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)deleteKeyQuery);
    return status == errSecSuccess;
}

- (SecKeyRef)keyRefOfRSAKeyWithTag:(NSString *)keyTag {
    NSAssert(keyTag.length > 0, @"key tag should be non-empty!");
    NSDictionary *query = @{
                            (__bridge id)kSecClass: (__bridge id)kSecClassKey,
                            (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
                            (__bridge id)kSecReturnRef: @YES,
                            (__bridge id)kSecAttrApplicationTag: keyTag,
                            };
    SecKeyRef privateKeyRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&privateKeyRef);
    if (status != errSecSuccess) {
        return NULL;
    }
    return privateKeyRef;
}

@end

@implementation A0SimpleKeychain (Deprecated)

- (NSData *)publicRSAKeyDataForTag:(NSString *)keyTag {
    return [self dataForRSAKeyWithTag:keyTag];
}

@end
