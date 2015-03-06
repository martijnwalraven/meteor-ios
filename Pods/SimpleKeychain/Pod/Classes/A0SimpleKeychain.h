//  A0SimpleKeychain.h
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

#import <Foundation/Foundation.h>

///---------------------------------------------------
/// @name Keychain Items Accessibility Values
///---------------------------------------------------

/**
 *  Enum with Kechain items accessibility types. It's a mirror of `kSecAttrAccessible` values.
 */
typedef NS_ENUM(NSInteger, A0SimpleKeychainItemAccessible) {
    /**
     *  @see kSecAttrAccessibleWhenUnlocked
     */
    A0SimpleKeychainItemAccessibleWhenUnlocked = 0,
    /**
     *  @see kSecAttrAccessibleAfterFirstUnlock
     */
    A0SimpleKeychainItemAccessibleAfterFirstUnlock,
    /**
     *  @see kSecAttrAccessibleAlways
     */
    A0SimpleKeychainItemAccessibleAlways,
    /**
     *  @see kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
     */
    A0SimpleKeychainItemAccessibleWhenPasscodeSetThisDeviceOnly,
    /**
     *  @see kSecAttrAccessibleWhenUnlockedThisDeviceOnly
     */
    A0SimpleKeychainItemAccessibleWhenUnlockedThisDeviceOnly,
    /**
     *  kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
     */
    A0SimpleKeychainItemAccessibleAfterFirstUnlockThisDeviceOnly,
    /**
     *  @see kSecAttrAccessibleAlwaysThisDeviceOnly
     */
    A0SimpleKeychainItemAccessibleAlwaysThisDeviceOnly
};

#define A0ErrorDomain @"com.auth0.simplekeychain"

/**
 * Enum with keychain error codes. It's a mirror of the keychain error codes. 
 */
typedef NS_ENUM(NSInteger, A0SimpleKeychainError) {
    /**
     * @see errSecSuccess
     */
    A0SimpleKeychainErrorNoError = 0,
    /**
     * @see errSecUnimplemented
     */
    A0SimpleKeychainErrorUnimplemented = -4,
    /**
     * @see errSecParam
     */
    A0SimpleKeychainErrorWrongParameter = -50,
    /**
     * @see errSecAllocate
     */
    A0SimpleKeychainErrorAllocation = -108,
    /**
     * @see errSecNotAvailable
     */
    A0SimpleKeychainErrorNotAvailable = -25291,
    /**
     * @see errSecAuthFailed
     */
    A0SimpleKeychainErrorAuthFailed = -25293,
    /**
     * @see errSecDuplicateItem
     */
    A0SimpleKeychainErrorDuplicateItem = -25299,
    /**
     * @see errSecItemNotFound
     */
    A0SimpleKeychainErrorItemNotFound = -25300,
    /**
     * @see errSecInteractionNotAllowed
     */
    A0SimpleKeychainErrorInteractionNotAllowed = -25308,
    /**
     * @see errSecDecode
     */
    A0SimpleKeychainErrorDecode = -26275
};

/**
 *  A simple helper class to deal with storing and retrieving values from iOS Keychain.
 *  It has support for sharing keychain items using Access Group and also for iOS 8 fine grained accesibility over a specific Kyechain Item (Using Access Control).
 *  The support is only available for iOS 8+, otherwise it will default using the coarse grained accesibility field.
 *  When a `NSString` or `NSData` is stored using Access Control and the accesibility flag `A0SimpleKeychainItemAccessibleWhenPasscodeSetThisDeviceOnly`, iOS will prompt the user for it's passcode or pass a TouchID challenge (if available).
 */
@interface A0SimpleKeychain : NSObject

/**
 *  Service name under all items are saved. Default value is Bundle Identifier.
 */
@property (readonly, nonatomic) NSString *service;
/**
 *  Access Group for Keychain item sharing. If it's nil no keychain sharing is possible. Default value is nil.
 */
@property (readonly, nonatomic) NSString *accessGroup;
/**
 *  What type of accessibility the items stored will have. All values are translated to `kSecAttrAccessible` constants.
 *  Default value is A0SimpleKeychainItemAccessibleAfterFirstUnlock.
 *  @see kSecAttrAccessible
 */
@property (assign, nonatomic) A0SimpleKeychainItemAccessible defaultAccessiblity;
/**
 *  Tells A0SimpleKeychain to use `kSecAttrAccessControl` instead of `kSecAttrAccessible`. It will work only in iOS 8+, defaulting to `kSecAttrAccessible` on lower version.
 *  Default value is NO.
 */
@property (assign, nonatomic) BOOL useAccessControl;


///---------------------------------------------------
/// @name Initialization
///---------------------------------------------------

/**
 *  Initialise a `A0SimpleKeychain` with default values.
 *
 *  @return an initialised instance
 */
- (instancetype)init;
/**
 *  Initialise a `A0SimpleKeychain` with a given service.
 *
 *  @param service name of the service to use to save items.
 *
 *  @return an initialised instance.
 */
- (instancetype)initWithService:(NSString *)service;
/**
 *  Initialise a `A0SimpleKeychain` with a given service and access group.
 *
 *  @param service name of the service to use to save items.
 *  @param accessGroup name of the access group to share items.
 *
 *  @return an initialised instance.
 */
- (instancetype)initWithService:(NSString *)service accessGroup:(NSString *)accessGroup;

///---------------------------------------------------
/// @name Store values
///---------------------------------------------------

/**
 *  Saves the NSString with the type `kSecClassGenericPassword` in the keychain.
 *
 *  @param string value to save in the keychain
 *  @param key    key for the keychain entry.
 *
 *  @return if the value was saved it will return YES. Otherwise it'll return NO.
 */
- (BOOL)setString:(NSString *)string forKey:(NSString *)key;
/**
 *  Saves the NSData with the type `kSecClassGenericPassword` in the keychain.
 *
 *  @param data value to save in the keychain
 *  @param key    key for the keychain entry.
 *
 *  @return if the value was saved it will return YES. Otherwise it'll return NO.
 */
- (BOOL)setData:(NSData *)data forKey:(NSString *)key;

/**
 *  Saves the NSString with the type `kSecClassGenericPassword` in the keychain.
 *
 *  @param string   value to save in the keychain
 *  @param key      key for the keychain entry.
 *  @param message  prompt message to display for TouchID/passcode prompt if neccesary
 *
 *  @return if the value was saved it will return YES. Otherwise it'll return NO.
 */
- (BOOL)setString:(NSString *)string forKey:(NSString *)key promptMessage:(NSString *)message;
/**
 *  Saves the NSData with the type `kSecClassGenericPassword` in the keychain.
 *
 *  @param string   value to save in the keychain
 *  @param key      key for the keychain entry.
 *  @param message  prompt message to display for TouchID/passcode prompt if neccesary
 *
 *  @return if the value was saved it will return YES. Otherwise it'll return NO.
 */
- (BOOL)setData:(NSData *)data forKey:(NSString *)key promptMessage:(NSString *)message;

///---------------------------------------------------
/// @name Remove values
///---------------------------------------------------

/**
 *  Removes an entry from the Keychain using its key
 *
 *  @param key the key of the entry to delete.
 *
 *  @return If the entry was removed it will return YES. Otherwise it will return NO.
 */
- (BOOL)deleteEntryForKey:(NSString *)key;
/**
 *  Remove all entries from the kechain with the service and access group values.
 */
- (void)clearAll;

///---------------------------------------------------
/// @name Obtain values
///---------------------------------------------------

/**
 *  Fetches a NSString from the keychain
 *
 *  @param key the key of the value to fetch
 *
 *  @return the value or nil if an error occurs.
 */
- (NSString *)stringForKey:(NSString *)key;

/**
 *  Fetches a NSData from the keychain
 *
 *  @param key the key of the value to fetch
 *
 *  @return the value or nil if an error occurs.
 */
- (NSData *)dataForKey:(NSString *)key;

/**
 *  Fetches a NSString from the keychain
 *
 *  @param key     the key of the value to fetch
 *  @param message prompt message to display for TouchID/passcode prompt if neccesary
 *
 *  @return the value or nil if an error occurs.
 */
- (NSString *)stringForKey:(NSString *)key promptMessage:(NSString *)message;
/**
 *  Fetches a NSData from the keychain
 *
 *  @param key     the key of the value to fetch
 *  @param message prompt message to display for TouchID/passcode prompt if neccesary
 *
 *  @return the value or nil if an error occurs.
 */
- (NSData *)dataForKey:(NSString *)key promptMessage:(NSString *)message;

/**
 *  Fetches a NSData from the keychain
 *
 *  @param key     the key of the value to fetch
 *  @param message prompt message to display for TouchID/passcode prompt if neccesary
 *  @param err     Returns an error, if the item cannot be retrieved. F.e. item not found 
 *                 or user authentication failed in TouchId case.
 *
 *  @return the value or nil if an error occurs.
 */
- (NSData *)dataForKey:(NSString *)key promptMessage:(NSString *)message error:(NSError**)err;

/**
 *  Checks if a key has a value in the Keychain
 *
 *  @param key the key to check if it has a value
 *
 *  @return if the key has an associated value in the Keychain or not.
 */
- (BOOL)hasValueForKey:(NSString *)key;

///---------------------------------------------------
/// @name Create helper methods
///---------------------------------------------------

/**
 *  Creates a new instance of `A0SimpleKeychain`
 *
 *  @return a new instance
 */
+ (A0SimpleKeychain *)keychain;
/**
 *  Creates a new instance of `A0SimpleKeychain` with a service name.
 *
 *  @param service name of the service under all items will be stored.
 *
 *  @return a new instance
 */
+ (A0SimpleKeychain *)keychainWithService:(NSString *)service;
/**
 *  Creates a new instance of `A0SimpleKeychain` with a service name and access group
 *
 *  @param service     name of the service under all items will be stored.
 *  @param accessGroup name of the access group to share keychain items.
 *
 *  @return a new instance
 */
+ (A0SimpleKeychain *)keychainWithService:(NSString *)service accessGroup:(NSString *)accessGroup;

@end
