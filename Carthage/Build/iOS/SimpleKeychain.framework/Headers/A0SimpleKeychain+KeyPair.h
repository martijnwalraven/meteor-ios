//  A0SimpleKeychain+KeyPair.h
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

#import "A0SimpleKeychain.h"

typedef NS_ENUM(NSUInteger, A0SimpleKeychainRSAKeySize) {
    A0SimpleKeychainRSAKeySize512Bits = 512,
    A0SimpleKeychainRSAKeySize1024Bits = 1024,
    A0SimpleKeychainRSAKeySize2048Bits = 2048
};

/**
 *  Category of `A0SimpleKeychain` to handle RSA pairs keys in the Keychain
 */
@interface A0SimpleKeychain (KeyPair)

/**
 *  Generates a RSA key pair with a specific length and tags. 
 *  Each key is marked as permanent in the Keychain
 *
 *  @param keyLength     number of bits of the keys.
 *  @param publicKeyTag  tag of the public key
 *  @param privateKeyTag tag of the private key
 *
 *  @return if the key par is created it will return YES, otherwise NO.
 */
- (BOOL)generateRSAKeyPairWithLength:(A0SimpleKeychainRSAKeySize)keyLength
                        publicKeyTag:(NSString *)publicKeyTag
                       privateKeyTag:(NSString *)privateKeyTag;

/**
 *  Returns a RSA key as NSData.
 *
 *  @param keyTag tag of the key
 *
 *  @return the key as NSData or nil if not found
 */
- (NSData *)dataForRSAKeyWithTag:(NSString *)keyTag;

/**
 *  Removes a key using its tag.
 *
 *  @param keyTag tag of the key to remove
 *
 *  @return if the key was removed successfuly.
 */
- (BOOL)deleteRSAKeyWithTag:(NSString *)keyTag;

/**
 *  Returns a RSA key as `SecKeyRef`. You must release it when you're done with it
 *
 *  @param keyTag tag of the RSA Key
 *
 *  @return SecKeyRef of RSA Key
 */
- (SecKeyRef)keyRefOfRSAKeyWithTag:(NSString *)keyTag;

/**
 *  Checks if a RSA key exists with a given tag.
 *
 *  @param keyTag tag of RSA Key
 *
 *  @return if the key exists or not.
 */
- (BOOL)hasRSAKeyWithTag:(NSString *)keyTag;

@end

@interface A0SimpleKeychain (Deprecated)

/**
 *  Returns the public key as NSData.
 *
 *  @param keyTag tag of the public key
 *
 *  @return the public key as NSData or nil if not found
 *  
 *  @deprecated 0.2.0
 */
- (NSData *)publicRSAKeyDataForTag:(NSString *)keyTag;

@end
