/*
 
 File: SecKeyWrapper.m
 Abstract: Core cryptographic wrapper class to exercise most of the Security 
 APIs on the iPhone OS. Start here if all you are interested in are the 
 cryptographic APIs on the iPhone OS.
 
 Version: 1.2
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple Inc.
 ("Apple") in consideration of your agreement to the following terms, and your
 use, installation, modification or redistribution of this Apple software
 constitutes acceptance of these terms.  If you do not agree with these terms,
 please do not use, install, modify or redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and subject
 to these terms, Apple grants you a personal, non-exclusive license, under
 Apple's copyrights in this original Apple software (the "Apple Software"), to
 use, reproduce, modify and redistribute the Apple Software, with or without
 modifications, in source and/or binary forms; provided that if you redistribute
 the Apple Software in its entirety and without modifications, you must retain
 this notice and the following text and disclaimers in all such redistributions
 of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may be used
 to endorse or promote products derived from the Apple Software without specific
 prior written permission from Apple.  Except as expressly stated in this notice,
 no other rights or licenses, express or implied, are granted by Apple herein,
 including but not limited to any patent rights that may be infringed by your
 derivative works or by other works in which the Apple Software may be
 incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
 WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
 WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
 COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR
 DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF
 CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF
 APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2008-2009 Apple Inc. All Rights Reserved.
 
 */

#import "SecKeyWrapper.h"
#import <Security/Security.h>

#include "X509CertificateHelper.h"

@implementation SecKeyWrapper

@synthesize publicTag, privateTag, symmetricTag, symmetricKeyRef;

#if DEBUG
	#define LOGGING_FACILITY(X, Y)	\
					NSAssert(X, Y);	

	#define LOGGING_FACILITY1(X, Y, Z)	\
					NSAssert1(X, Y, Z);	
#else
	#define LOGGING_FACILITY(X, Y)	\
				if (!(X)) {			\
					NSLog(Y);		\
				}

	#define LOGGING_FACILITY1(X, Y, Z)	\
				if (!(X)) {				\
					NSLog(Y, Z);		\
				}						
#endif

#if TARGET_IPHONE_SIMULATOR
//#error This sample is designed to run on a device, not in the simulator. To run this sample, \
choose Project > Set Active SDK > Device and connect a device. Then click Build and Go.
// Dummy implementations for no-building simulator target (reduce compiler warnings)
+ (SecKeyWrapper *)sharedWrapper { return nil; }
- (void)setObject:(id)inObject forKey:(id)key {}
- (id)objectForKey:(id)key { return nil; }
// Dummy implementations for my SecKeyWrapper class.
- (void)generateKeyPair:(NSUInteger)keySize {}
- (void)deleteAsymmetricKeys {}
- (void)deleteSymmetricKey {}
- (void)generateSymmetricKey {}
- (NSData *)getSymmetricKeyBytes { return NULL; }
- (SecKeyRef)addPeerPublicKey:(NSString *)peerName keyBits:(NSData *)publicKey { return NULL; }
- (void)removePeerPublicKey:(NSString *)peerName {}
- (NSData *)wrapSymmetricKey:(NSData *)symmetricKey keyRef:(SecKeyRef)publicKey { return nil; }
- (NSData *)unwrapSymmetricKey:(NSData *)wrappedSymmetricKey { return nil; }
- (NSData *)getSignatureBytes:(NSData *)plainText { return nil; }
- (NSData *)getHashBytes:(NSData *)plainText { return nil; }
- (BOOL)verifySignature:(NSData *)plainText secKeyRef:(SecKeyRef)publicKey signature:(NSData *)sig { return NO; }
- (NSData *)doCipher:(NSData *)plainText key:(NSData *)symmetricKey context:(CCOperation)encryptOrDecrypt padding:(CCOptions *)pkcs7 { return nil; } 
- (SecKeyRef)getPublicKeyRef { return nil; }
- (NSData *)getPublicKeyBits { return nil; }
- (SecKeyRef)getPrivateKeyRef { return nil; }
- (CFTypeRef)getPersistentKeyRefWithKeyRef:(SecKeyRef)keyRef { return NULL; }
- (SecKeyRef)getKeyRefWithPersistentKeyRef:(CFTypeRef)persistentRef { return NULL; }
#else

// (See cssmtype.h and cssmapple.h on the Mac OS X SDK.)

enum {
	CSSM_ALGID_NONE =					0x00000000L,
	CSSM_ALGID_VENDOR_DEFINED =			CSSM_ALGID_NONE + 0x80000000L,
	CSSM_ALGID_AES
};

// identifiers used to find public, private, and symmetric key.
static const uint8_t publicKeyIdentifier[]		= kPublicKeyTag;
static const uint8_t privateKeyIdentifier[]		= kPrivateKeyTag;
static const uint8_t symmetricKeyIdentifier[]	= kSymmetricKeyTag;

static SecKeyWrapper * __sharedKeyWrapper = nil;

/* Begin method definitions */

+ (SecKeyWrapper *)sharedWrapper {
    @synchronized(self) {
        if (__sharedKeyWrapper == nil) {
            [[self alloc] init];
        }
    }
    return __sharedKeyWrapper;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (__sharedKeyWrapper == nil) {
            __sharedKeyWrapper = [super allocWithZone:zone];
            return __sharedKeyWrapper;
        }
    }
    return nil;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (void)release {
}

- (id)retain {
    return self;
}

- (id)autorelease {
    return self;
}

- (NSUInteger)retainCount {
    return UINT_MAX;
}

-(id)init {
	 if (self = [super init])
	 {
		 // Tag data to search for keys.
		 privateTag = [[NSData alloc] initWithBytes:privateKeyIdentifier length:sizeof(privateKeyIdentifier)];
		 publicTag = [[NSData alloc] initWithBytes:publicKeyIdentifier length:sizeof(publicKeyIdentifier)];
		 symmetricTag = [[NSData alloc] initWithBytes:symmetricKeyIdentifier length:sizeof(symmetricKeyIdentifier)];
	 }
	
	return self;
}

- (void)deleteAsymmetricKeys {
	OSStatus sanityCheck = noErr;
	NSMutableDictionary * queryPublicKey = [[NSMutableDictionary alloc] init];
	NSMutableDictionary * queryPrivateKey = [[NSMutableDictionary alloc] init];
	
	// Set the public key query dictionary.
	[queryPublicKey setObject:(id)kSecClassKey forKey:(id)kSecClass];
	[queryPublicKey setObject:publicTag forKey:(id)kSecAttrApplicationTag];
	[queryPublicKey setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
	
	// Set the private key query dictionary.
	[queryPrivateKey setObject:(id)kSecClassKey forKey:(id)kSecClass];
	[queryPrivateKey setObject:privateTag forKey:(id)kSecAttrApplicationTag];
	[queryPrivateKey setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
	
	// Delete the private key.
	sanityCheck = SecItemDelete((CFDictionaryRef)queryPrivateKey);
	LOGGING_FACILITY1( sanityCheck == noErr || sanityCheck == errSecItemNotFound, @"Error removing private key, OSStatus == %d.", sanityCheck );
	
	// Delete the public key.
	sanityCheck = SecItemDelete((CFDictionaryRef)queryPublicKey);
	LOGGING_FACILITY1( sanityCheck == noErr || sanityCheck == errSecItemNotFound, @"Error removing public key, OSStatus == %d.", sanityCheck );
	
	[queryPrivateKey release];
	[queryPublicKey release];
	if (publicKeyRef) CFRelease(publicKeyRef);
	if (privateKeyRef) CFRelease(privateKeyRef);
}

- (void)deleteSymmetricKey {
	OSStatus sanityCheck = noErr;
	
	NSMutableDictionary * querySymmetricKey = [[NSMutableDictionary alloc] init];
	
	// Set the symmetric key query dictionary.
	[querySymmetricKey setObject:(id)kSecClassKey forKey:(id)kSecClass];
	[querySymmetricKey setObject:symmetricTag forKey:(id)kSecAttrApplicationTag];
	[querySymmetricKey setObject:[NSNumber numberWithUnsignedInt:CSSM_ALGID_AES] forKey:(id)kSecAttrKeyType];
	
	// Delete the symmetric key.
	sanityCheck = SecItemDelete((CFDictionaryRef)querySymmetricKey);
	LOGGING_FACILITY1( sanityCheck == noErr || sanityCheck == errSecItemNotFound, @"Error removing symmetric key, OSStatus == %d.", sanityCheck );
	
	[querySymmetricKey release];
	[symmetricKeyRef release];
}

- (void)generateKeyPair:(NSUInteger)keySize {
	OSStatus sanityCheck = noErr;
	publicKeyRef = NULL;
	privateKeyRef = NULL;
	
//	LOGGING_FACILITY1( keySize == 512 || keySize == 1024 || keySize == 2048, @"%d is an invalid and unsupported key size.", keySize );
	
	// First delete current keys.
	[self deleteAsymmetricKeys];
	
	// Container dictionaries.
	NSMutableDictionary * privateKeyAttr = [[NSMutableDictionary alloc] init];
	NSMutableDictionary * publicKeyAttr = [[NSMutableDictionary alloc] init];
	NSMutableDictionary * keyPairAttr = [[NSMutableDictionary alloc] init];
	
	// Set top level dictionary for the keypair.
	[keyPairAttr setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
	[keyPairAttr setObject:[NSNumber numberWithUnsignedInteger:keySize] forKey:(id)kSecAttrKeySizeInBits];
	
	// Set the private key dictionary.
	[privateKeyAttr setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecAttrIsPermanent];
	[privateKeyAttr setObject:privateTag forKey:(id)kSecAttrApplicationTag];
	// See SecKey.h to set other flag values.
	
	// Set the public key dictionary.
	[publicKeyAttr setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecAttrIsPermanent];
	[publicKeyAttr setObject:publicTag forKey:(id)kSecAttrApplicationTag];
	// See SecKey.h to set other flag values.
	
	// Set attributes to top level dictionary.
	[keyPairAttr setObject:privateKeyAttr forKey:(id)kSecPrivateKeyAttrs];
	[keyPairAttr setObject:publicKeyAttr forKey:(id)kSecPublicKeyAttrs];
	
	// SecKeyGeneratePair returns the SecKeyRefs just for educational purposes.
	sanityCheck = SecKeyGeneratePair((CFDictionaryRef)keyPairAttr, &publicKeyRef, &privateKeyRef);
	LOGGING_FACILITY( sanityCheck == noErr && publicKeyRef != NULL && privateKeyRef != NULL, @"Something really bad went wrong with generating the key pair." );
	
	[privateKeyAttr release];
	[publicKeyAttr release];
	[keyPairAttr release];
}

- (void)generateSymmetricKey {
	OSStatus sanityCheck = noErr;
	uint8_t * symmetricKey = NULL;
	
	// First delete current symmetric key.
	[self deleteSymmetricKey];
	
	// Container dictionary
	NSMutableDictionary *symmetricKeyAttr = [[NSMutableDictionary alloc] init];
	[symmetricKeyAttr setObject:(id)kSecClassKey forKey:(id)kSecClass];
	[symmetricKeyAttr setObject:symmetricTag forKey:(id)kSecAttrApplicationTag];
	[symmetricKeyAttr setObject:[NSNumber numberWithUnsignedInt:CSSM_ALGID_AES] forKey:(id)kSecAttrKeyType];
	[symmetricKeyAttr setObject:[NSNumber numberWithUnsignedInt:(unsigned int)(kChosenCipherKeySize << 3)] forKey:(id)kSecAttrKeySizeInBits];
	[symmetricKeyAttr setObject:[NSNumber numberWithUnsignedInt:(unsigned int)(kChosenCipherKeySize << 3)]	forKey:(id)kSecAttrEffectiveKeySize];
	[symmetricKeyAttr setObject:(id)kCFBooleanTrue forKey:(id)kSecAttrCanEncrypt];
	[symmetricKeyAttr setObject:(id)kCFBooleanTrue forKey:(id)kSecAttrCanDecrypt];
	[symmetricKeyAttr setObject:(id)kCFBooleanFalse forKey:(id)kSecAttrCanDerive];
	[symmetricKeyAttr setObject:(id)kCFBooleanFalse forKey:(id)kSecAttrCanSign];
	[symmetricKeyAttr setObject:(id)kCFBooleanFalse forKey:(id)kSecAttrCanVerify];
	[symmetricKeyAttr setObject:(id)kCFBooleanFalse forKey:(id)kSecAttrCanWrap];
	[symmetricKeyAttr setObject:(id)kCFBooleanFalse forKey:(id)kSecAttrCanUnwrap];
	
	// Allocate some buffer space. I don't trust calloc.
	symmetricKey = malloc( kChosenCipherKeySize * sizeof(uint8_t) );
	
	LOGGING_FACILITY( symmetricKey != NULL, @"Problem allocating buffer space for symmetric key generation." );
	
	memset((void *)symmetricKey, 0x0, kChosenCipherKeySize);
	
	sanityCheck = SecRandomCopyBytes(kSecRandomDefault, kChosenCipherKeySize, symmetricKey);
	LOGGING_FACILITY1( sanityCheck == noErr, @"Problem generating the symmetric key, OSStatus == %d.", sanityCheck );
	
	self.symmetricKeyRef = [[NSData alloc] initWithBytes:(const void *)symmetricKey length:kChosenCipherKeySize];
	
	// Add the wrapped key data to the container dictionary.
	[symmetricKeyAttr setObject:self.symmetricKeyRef
					  forKey:(id)kSecValueData];
	
	// Add the symmetric key to the keychain.
	sanityCheck = SecItemAdd((CFDictionaryRef) symmetricKeyAttr, NULL);
	LOGGING_FACILITY1( sanityCheck == noErr || sanityCheck == errSecDuplicateItem, @"Problem storing the symmetric key in the keychain, OSStatus == %d.", sanityCheck );
	
	if (symmetricKey) free(symmetricKey);
	[symmetricKeyAttr release];
}

- (SecCertificateRef)addPeerCertificate:(NSString *)peerName keyBits:(NSData *)certificate {
	OSStatus sanityCheck = noErr;
	SecCertificateRef peerCertificateRef = NULL;
	CFTypeRef persistPeer = NULL;
	
	LOGGING_FACILITY( peerName != nil, @"Peer name parameter is nil." );
	LOGGING_FACILITY( certificate != nil, @"Certificate parameter is nil." );
	
	NSData * peerTag = [[NSData alloc] initWithBytes:(const void *)[peerName UTF8String] length:[peerName length]];
	NSMutableDictionary * peerCertificateAttr = [[NSMutableDictionary alloc] init];
	
	[peerCertificateAttr setObject:(id)kSecClassCertificate forKey:(id)kSecClass];
	[peerCertificateAttr setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
	[peerCertificateAttr setObject:peerTag forKey:(id)kSecAttrApplicationTag];
	[peerCertificateAttr setObject:certificate forKey:(id)kSecValueData];
	[peerCertificateAttr setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnPersistentRef];
	
	sanityCheck = SecItemAdd((CFDictionaryRef) peerCertificateAttr, (CFTypeRef *)&persistPeer);
	
	// The nice thing about persistent references is that you can write their value out to disk and
	// then use them later. I don't do that here but it certainly can make sense for other situations
	// where you don't want to have to keep building up dictionaries of attributes to get a reference.
	// 
	// Also take a look at SecKeyWrapper's methods (CFTypeRef)getPersistentKeyRefWithKeyRef:(SecKeyRef)key
	// & (SecKeyRef)getKeyRefWithPersistentKeyRef:(CFTypeRef)persistentRef.
	
	LOGGING_FACILITY1( sanityCheck == noErr || sanityCheck == errSecDuplicateItem, @"Problem adding the peer Certificate to the keychain, OSStatus == %d.", sanityCheck );
	
	if (persistPeer) {
		peerCertificateRef = [self getKeyRefWithPersistentKeyRef:persistPeer];
	} else {
		[peerCertificateAttr removeObjectForKey:(id)kSecValueData];
		[peerCertificateAttr setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnRef];
		// Let's retry a different way.
		sanityCheck = SecItemCopyMatching((CFDictionaryRef) peerCertificateAttr, (CFTypeRef *)&peerCertificateRef);
	}
	
	LOGGING_FACILITY1( sanityCheck == noErr && peerCertificateRef != NULL, @"Problem acquiring reference to the Certificate, OSStatus == %d.", sanityCheck );
	
	[peerTag release];
	[peerCertificateAttr release];
	if (persistPeer) CFRelease(persistPeer);
	return peerCertificateRef;
}

- (SecKeyRef)addPeerRSAPublicKey:(NSString *)peerName keyBits:(NSData *)publicKey {
    NSRange range;
    range.length=[publicKey length]-24*sizeof(uint8_t);
    range.location=24*sizeof(uint8_t);
    NSData* keybits=[publicKey subdataWithRange:range];
    return [self addPeerPublicKey:peerName keyBits:keybits];
}


- (void)removePeerCertificate:(NSString *)peerName {
	OSStatus sanityCheck = noErr;
	
	LOGGING_FACILITY( peerName != nil, @"Peer name parameter is nil." );
	
	NSData * peerTag = [[NSData alloc] initWithBytes:(const void *)[peerName UTF8String] length:[peerName length]];
	NSMutableDictionary * peerCertificateAttr = [[NSMutableDictionary alloc] init];
	
	[peerCertificateAttr setObject:(id)kSecClassCertificate forKey:(id)kSecClass];
	[peerCertificateAttr setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
	[peerCertificateAttr setObject:peerTag forKey:(id)kSecAttrApplicationTag];
	
	sanityCheck = SecItemDelete((CFDictionaryRef) peerCertificateAttr);
	
	LOGGING_FACILITY1( sanityCheck == noErr || sanityCheck == errSecItemNotFound, @"Problem deleting the peer Certificate to the keychain, OSStatus == %d.", sanityCheck );
	
	[peerTag release];
	[peerCertificateAttr release];
}

- (NSData *)wrapSymmetricKey:(NSData *)symmetricKey keyRef:(SecKeyRef)publicKey {
	OSStatus sanityCheck = noErr;
	size_t cipherBufferSize = 0;
	size_t keyBufferSize = 0;
	
	LOGGING_FACILITY( symmetricKey != nil, @"Symmetric key parameter is nil." );
	LOGGING_FACILITY( publicKey != nil, @"Key parameter is nil." );
	
	NSData * cipher = nil;
	uint8_t * cipherBuffer = NULL;
	
	// Calculate the buffer sizes.
	cipherBufferSize = SecKeyGetBlockSize(publicKey);
	keyBufferSize = [symmetricKey length];
	
	if (kTypeOfWrapPadding == kSecPaddingNone) {
		LOGGING_FACILITY( keyBufferSize <= cipherBufferSize, @"Nonce integer is too large and falls outside multiplicative group." );
	} else {
		LOGGING_FACILITY( keyBufferSize <= (cipherBufferSize - 11), @"Nonce integer is too large and falls outside multiplicative group." );
	}
	
	// Allocate some buffer space. I don't trust calloc.
	cipherBuffer = malloc( cipherBufferSize * sizeof(uint8_t) );
	memset((void *)cipherBuffer, 0x0, cipherBufferSize);
	
	// Encrypt using the public key.
	sanityCheck = SecKeyEncrypt(	publicKey,
									kTypeOfWrapPadding,
									(const uint8_t *)[symmetricKey bytes],
									keyBufferSize,
									cipherBuffer,
									&cipherBufferSize
								);
	
	LOGGING_FACILITY1( sanityCheck == noErr, @"Error encrypting, OSStatus == %d.", sanityCheck );
	
	// Build up cipher text blob.
	cipher = [NSData dataWithBytes:(const void *)cipherBuffer length:(NSUInteger)cipherBufferSize];
	
	if (cipherBuffer) free(cipherBuffer);
	
	return cipher;
}

- (NSData *)unwrapSymmetricKey:(NSData *)wrappedSymmetricKey {
	OSStatus sanityCheck = noErr;
	size_t cipherBufferSize = 0;
	size_t keyBufferSize = 0;
	
	NSData * key = nil;
	uint8_t * keyBuffer = NULL;
	
	SecKeyRef privateKey = NULL;
	
	privateKey = [self getPrivateKeyRef];
	LOGGING_FACILITY( privateKey != NULL, @"No private key found in the keychain." );
	
	// Calculate the buffer sizes.
	cipherBufferSize = SecKeyGetBlockSize(privateKey);
	keyBufferSize = [wrappedSymmetricKey length];
	
	LOGGING_FACILITY( keyBufferSize <= cipherBufferSize, @"Encrypted nonce is too large and falls outside multiplicative group." );
	
	// Allocate some buffer space. I don't trust calloc.
	keyBuffer = malloc( keyBufferSize * sizeof(uint8_t) );
	memset((void *)keyBuffer, 0x0, keyBufferSize);
	
	// Decrypt using the private key.
	sanityCheck = SecKeyDecrypt(	privateKey,
									kTypeOfWrapPadding,
									(const uint8_t *) [wrappedSymmetricKey bytes],
									cipherBufferSize,
									keyBuffer,
									&keyBufferSize
								);
	
	LOGGING_FACILITY1( sanityCheck == noErr, @"Error decrypting, OSStatus == %d.", sanityCheck );
	
	// Build up plain text blob.
	key = [NSData dataWithBytes:(const void *)keyBuffer length:(NSUInteger)keyBufferSize];
	
	if (keyBuffer) free(keyBuffer);
	
	return key;
}

- (NSData *)getHashBytes:(NSData *)plainText {
	CC_SHA1_CTX ctx;
	uint8_t * hashBytes = NULL;
	NSData * hash = nil;
	
	// Malloc a buffer to hold hash.
	hashBytes = malloc( kChosenDigestLength * sizeof(uint8_t) );
	memset((void *)hashBytes, 0x0, kChosenDigestLength);
	
	// Initialize the context.
	CC_SHA1_Init(&ctx);
	// Perform the hash.
	CC_SHA1_Update(&ctx, (void *)[plainText bytes], [plainText length]);
	// Finalize the output.
	CC_SHA1_Final(hashBytes, &ctx);
	
	// Build up the SHA1 blob.
	hash = [NSData dataWithBytes:(const void *)hashBytes length:(NSUInteger)kChosenDigestLength];
	
	if (hashBytes) free(hashBytes);
	
	return hash;
}

- (NSData *)getSignatureBytes:(NSData *)plainText {
	OSStatus sanityCheck = noErr;
	NSData * signedHash = nil;
	
	uint8_t * signedHashBytes = NULL;
	size_t signedHashBytesSize = 0;
	
	SecKeyRef privateKey = NULL;
	
	privateKey = [self getPrivateKeyRef];
	signedHashBytesSize = SecKeyGetBlockSize(privateKey);
	
	// Malloc a buffer to hold signature.
	signedHashBytes = malloc( signedHashBytesSize * sizeof(uint8_t) );
	memset((void *)signedHashBytes, 0x0, signedHashBytesSize);
	
	// Sign the SHA1 hash.
	sanityCheck = SecKeyRawSign(	privateKey, 
									kTypeOfSigPadding, 
									(const uint8_t *)[[self getHashBytes:plainText] bytes], 
									kChosenDigestLength, 
									(uint8_t *)signedHashBytes, 
									&signedHashBytesSize
								);
	
	LOGGING_FACILITY1( sanityCheck == noErr, @"Problem signing the SHA1 hash, OSStatus == %d.", sanityCheck );
	
	// Build up signed SHA1 blob.
	signedHash = [NSData dataWithBytes:(const void *)signedHashBytes length:(NSUInteger)signedHashBytesSize];
	
	if (signedHashBytes) free(signedHashBytes);
	
	return signedHash;
}

- (BOOL)verifySignature:(NSData *)plainText secKeyRef:(SecKeyRef)publicKey signature:(NSData *)sig {
	size_t signedHashBytesSize = 0;
	OSStatus sanityCheck = noErr;
	
	// Get the size of the assymetric block.
	signedHashBytesSize = SecKeyGetBlockSize(publicKey);
	
	sanityCheck = SecKeyRawVerify(	publicKey, 
									kTypeOfSigPadding, 
									(const uint8_t *)[[self getHashBytes:plainText] bytes],
									kChosenDigestLength, 
									(const uint8_t *)[sig bytes],
									signedHashBytesSize
								  );
	
	return (sanityCheck == noErr) ? YES : NO;
}

- (NSData *)doCipher:(NSData *)plainText key:(NSData *)symmetricKey context:(CCOperation)encryptOrDecrypt padding:(CCOptions *)pkcs7 {
	CCCryptorStatus ccStatus = kCCSuccess;
	// Symmetric crypto reference.
	CCCryptorRef thisEncipher = NULL;
	// Cipher Text container.
	NSData * cipherOrPlainText = nil;
	// Pointer to output buffer.
	uint8_t * bufferPtr = NULL;
	// Total size of the buffer.
	size_t bufferPtrSize = 0;
	// Remaining bytes to be performed on.
	size_t remainingBytes = 0;
	// Number of bytes moved to buffer.
	size_t movedBytes = 0;
	// Length of plainText buffer.
	size_t plainTextBufferSize = 0;
	// Placeholder for total written.
	size_t totalBytesWritten = 0;
	// A friendly helper pointer.
	uint8_t * ptr;
	
	// Initialization vector; dummy in this case 0's.
	uint8_t iv[kChosenCipherBlockSize];
	memset((void *) iv, 0x0, (size_t) sizeof(iv));
	
	LOGGING_FACILITY(plainText != nil, @"PlainText object cannot be nil." );
	LOGGING_FACILITY(symmetricKey != nil, @"Symmetric key object cannot be nil." );
	LOGGING_FACILITY(pkcs7 != NULL, @"CCOptions * pkcs7 cannot be NULL." );
	LOGGING_FACILITY([symmetricKey length] == kChosenCipherKeySize, @"Disjoint choices for key size." );
			 
	plainTextBufferSize = [plainText length];
	
	LOGGING_FACILITY(plainTextBufferSize > 0, @"Empty plaintext passed in." );
	
	// We don't want to toss padding on if we don't need to
	if (encryptOrDecrypt == kCCEncrypt) {
		if (*pkcs7 != kCCOptionECBMode) {
			if ((plainTextBufferSize % kChosenCipherBlockSize) == 0) {
				*pkcs7 = 0x0000;
			} else {
				*pkcs7 = kCCOptionPKCS7Padding;
			}
		}
	} else if (encryptOrDecrypt != kCCDecrypt) {
		LOGGING_FACILITY1( 0, @"Invalid CCOperation parameter [%d] for cipher context.", *pkcs7 );
	} 
	
	// Create and Initialize the crypto reference.
	ccStatus = CCCryptorCreate(	encryptOrDecrypt, 
								kCCAlgorithmAES128, 
								*pkcs7, 
								(const void *)[symmetricKey bytes], 
								kChosenCipherKeySize, 
								(const void *)iv, 
								&thisEncipher
							);
	
	LOGGING_FACILITY1( ccStatus == kCCSuccess, @"Problem creating the context, ccStatus == %d.", ccStatus );
	
	// Calculate byte block alignment for all calls through to and including final.
	bufferPtrSize = CCCryptorGetOutputLength(thisEncipher, plainTextBufferSize, true);
	
	// Allocate buffer.
	bufferPtr = malloc( bufferPtrSize * sizeof(uint8_t) );
	
	// Zero out buffer.
	memset((void *)bufferPtr, 0x0, bufferPtrSize);
	
	// Initialize some necessary book keeping.
	
	ptr = bufferPtr;
	
	// Set up initial size.
	remainingBytes = bufferPtrSize;
	
	// Actually perform the encryption or decryption.
	ccStatus = CCCryptorUpdate( thisEncipher,
								(const void *) [plainText bytes],
								plainTextBufferSize,
								ptr,
								remainingBytes,
								&movedBytes
							);
	
	LOGGING_FACILITY1( ccStatus == kCCSuccess, @"Problem with CCCryptorUpdate, ccStatus == %d.", ccStatus );
	
	// Handle book keeping.
	ptr += movedBytes;
	remainingBytes -= movedBytes;
	totalBytesWritten += movedBytes;
	
	// Finalize everything to the output buffer.
	ccStatus = CCCryptorFinal(	thisEncipher,
								ptr,
								remainingBytes,
								&movedBytes
							);
	
	totalBytesWritten += movedBytes;
	
	if (thisEncipher) {
		(void) CCCryptorRelease(thisEncipher);
		thisEncipher = NULL;
	}
	
	LOGGING_FACILITY1( ccStatus == kCCSuccess, @"Problem with encipherment ccStatus == %d", ccStatus );
	
	cipherOrPlainText = [NSData dataWithBytes:(const void *)bufferPtr length:(NSUInteger)totalBytesWritten];

	if (bufferPtr) free(bufferPtr);
	
	return cipherOrPlainText;
	
	/*
	 Or the corresponding one-shot call:
	 
	 ccStatus = CCCrypt(	encryptOrDecrypt,
							kCCAlgorithmAES128,
							typeOfSymmetricOpts,
							(const void *)[self getSymmetricKeyBytes],
							kChosenCipherKeySize,
							iv,
							(const void *) [plainText bytes],
							plainTextBufferSize,
							(void *)bufferPtr,
							bufferPtrSize,
							&movedBytes
						);
	 */
}

- (NSData*)encryptDataToData:(NSData*)data withPublicKeyRef:(SecKeyRef)publickey
{
    NSArray* encryptedArray=[self encryptDataToArray:data withPublicKeyRef:publickey];
    NSMutableData* encryptedData=[NSMutableData data];
    for (NSData* d in encryptedArray) {
        [encryptedData appendData:d];
    }
    return encryptedData;
}

- (NSArray*)encryptDataToArray:(NSData *)data withPublicKeyRef:(SecKeyRef)publickey
{
    NSRange range;
    range.length=SecKeyGetBlockSize(publickey)-11;
    range.location=0;
    NSUInteger length=[data length];
    NSMutableArray* encryptedArray=[NSMutableArray arrayWithCapacity:1];
    while (length>0) {
        if (length<range.length) {
            range.length=length;
            length=0;
        }
        else{
            length-=range.length;
        }
        NSData* chunk=[data subdataWithRange:range];
        range.location+=range.length;
        chunk=[self wrapSymmetricKey:chunk keyRef:publickey];
        [encryptedArray addObject:[chunk base64EncodedStringWithOptions:0]];
    }
    return encryptedArray;
}

- (NSData*)decryptData:(NSData*)data
{
    NSMutableArray* encryptedArray=[NSMutableArray array];
    NSRange range;
    range.length=SecKeyGetBlockSize([self getPrivateKeyRef]);
    range.location=0;
    NSUInteger length=[data length];
    while (length>0) {
        if (length<range.length) {
            range.length=length;
            length=0;
        }
        else{
            length-=range.length;
        }
        NSData* chunk=[data subdataWithRange:range];
        range.location+=range.length;
        [encryptedArray addObject:[chunk base64EncodedStringWithOptions:0]];
    }
    return [self decryptDataArray:encryptedArray];
}

- (NSData*)decryptDataArray:(NSArray *)dataArray
{
    NSMutableData* decrypted=[NSMutableData data];
    for (NSString* dataStr in dataArray) {
        NSData* encryptedData=[[NSData alloc] initWithBase64EncodedString:dataStr options:NSDataBase64DecodingIgnoreUnknownCharacters];
        NSData* decryptedData=[[SecKeyWrapper sharedWrapper] unwrapSymmetricKey:encryptedData];
        [decrypted appendData:decryptedData];
    }
    return decrypted;
}

- (SecKeyRef)getPublicKeyRef {
	OSStatus sanityCheck = noErr;
	SecKeyRef publicKeyReference = NULL;
	
	if (publicKeyRef == NULL) {
		NSMutableDictionary * queryPublicKey = [[NSMutableDictionary alloc] init];
		
		// Set the public key query dictionary.
		[queryPublicKey setObject:(id)kSecClassKey forKey:(id)kSecClass];
		[queryPublicKey setObject:publicTag forKey:(id)kSecAttrApplicationTag];
		[queryPublicKey setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
		[queryPublicKey setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnRef];
		
		// Get the key.
		sanityCheck = SecItemCopyMatching((CFDictionaryRef)queryPublicKey, (CFTypeRef *)&publicKeyReference);
		
		if (sanityCheck != noErr)
		{
			publicKeyReference = NULL;
		}
		
		[queryPublicKey release];
	} else {
		publicKeyReference = publicKeyRef;
	}
	
	return publicKeyReference;
}

- (SecKeyRef)getPeerPublicKeyRef:(NSString*)peerName {
    OSStatus sanityCheck = noErr;
	SecKeyRef peerKeyRef = NULL;
	
	LOGGING_FACILITY( peerName != nil, @"Peer name parameter is nil." );
	
	NSData * peerTag = [[NSData alloc] initWithBytes:(const void *)[peerName UTF8String] length:[peerName length]];
	NSMutableDictionary * peerPublicKeyAttr = [[NSMutableDictionary alloc] init];
	
	[peerPublicKeyAttr setObject:(id)kSecClassKey forKey:(id)kSecClass];
	[peerPublicKeyAttr setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
	[peerPublicKeyAttr setObject:peerTag forKey:(id)kSecAttrApplicationTag];
	[peerPublicKeyAttr setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnPersistentRef];
    [peerPublicKeyAttr setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnRef];

    sanityCheck = SecItemCopyMatching((CFDictionaryRef) peerPublicKeyAttr, (CFTypeRef *)&peerKeyRef);

//	LOGGING_FACILITY1( sanityCheck == noErr , @"Problem acquiring reference to the public key, OSStatus == %d.", (int)sanityCheck );
	
	[peerTag release];
	[peerPublicKeyAttr release];
	return peerKeyRef;
}

- (NSData *)getPublicKeyBits {
	OSStatus sanityCheck = noErr;
	NSData * publicKeyBits = nil;
	
	NSMutableDictionary * queryPublicKey = [[NSMutableDictionary alloc] init];
		
	// Set the public key query dictionary.
	[queryPublicKey setObject:(id)kSecClassKey forKey:(id)kSecClass];
	[queryPublicKey setObject:publicTag forKey:(id)kSecAttrApplicationTag];
	[queryPublicKey setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
	[queryPublicKey setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnData];
		
	// Get the key bits.
	sanityCheck = SecItemCopyMatching((CFDictionaryRef)queryPublicKey, (CFTypeRef *)&publicKeyBits);
		
	if (sanityCheck != noErr)
	{
		publicKeyBits = nil;
	}
		
	[queryPublicKey release];
	
	return publicKeyBits;
}

- (SecKeyRef)getPrivateKeyRef {
	OSStatus sanityCheck = noErr;
	SecKeyRef privateKeyReference = NULL;
	
	if (privateKeyRef == NULL) {
		NSMutableDictionary * queryPrivateKey = [[NSMutableDictionary alloc] init];
		
		// Set the private key query dictionary.
		[queryPrivateKey setObject:(id)kSecClassKey forKey:(id)kSecClass];
		[queryPrivateKey setObject:privateTag forKey:(id)kSecAttrApplicationTag];
		[queryPrivateKey setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
		[queryPrivateKey setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnRef];
		
		// Get the key.
		sanityCheck = SecItemCopyMatching((CFDictionaryRef)queryPrivateKey, (CFTypeRef *)&privateKeyReference);
		
		if (sanityCheck != noErr)
		{
			privateKeyReference = NULL;
		}
		
		[queryPrivateKey release];
	} else {
		privateKeyReference = privateKeyRef;
	}
	
	return privateKeyReference;
}

- (NSData *)getPrivateKeyBits {
    OSStatus sanityCheck = noErr;
    NSData * privateKeyBits = nil;
    
    NSMutableDictionary * queryPrivateKey = [[NSMutableDictionary alloc] init];
        
    // Set the private key query dictionary.
    [queryPrivateKey setObject:(id)kSecClassKey forKey:(id)kSecClass];
    [queryPrivateKey setObject:privateTag forKey:(id)kSecAttrApplicationTag];
    [queryPrivateKey setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
    [queryPrivateKey setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnData];
        
    // Get the key bits.
    sanityCheck = SecItemCopyMatching((CFDictionaryRef)queryPrivateKey, (CFTypeRef *)&privateKeyBits);
        
    if (sanityCheck != noErr)
    {
        privateKeyBits = nil;
    }
        
    [queryPrivateKey release];
    
    return privateKeyBits;
}

- (NSData *)getSymmetricKeyBytes {
	OSStatus sanityCheck = noErr;
	NSData * symmetricKeyReturn = nil;
	
	if (self.symmetricKeyRef == nil) {
		NSMutableDictionary * querySymmetricKey = [[NSMutableDictionary alloc] init];
		
		// Set the private key query dictionary.
		[querySymmetricKey setObject:(id)kSecClassKey forKey:(id)kSecClass];
		[querySymmetricKey setObject:symmetricTag forKey:(id)kSecAttrApplicationTag];
		[querySymmetricKey setObject:[NSNumber numberWithUnsignedInt:CSSM_ALGID_AES] forKey:(id)kSecAttrKeyType];
		[querySymmetricKey setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnData];
		
		// Get the key bits.
		sanityCheck = SecItemCopyMatching((CFDictionaryRef)querySymmetricKey, (CFTypeRef *)&symmetricKeyReturn);
		
		if (sanityCheck == noErr && symmetricKeyReturn != nil) {
			self.symmetricKeyRef = symmetricKeyReturn;
		} else {
			self.symmetricKeyRef = nil;
		}
		
		[querySymmetricKey release];
	} else {
		symmetricKeyReturn = self.symmetricKeyRef;
	}

	return symmetricKeyReturn;
}

- (CFTypeRef)getPersistentKeyRefWithKeyRef:(SecKeyRef)keyRef {
	OSStatus sanityCheck = noErr;
	CFTypeRef persistentRef = NULL;
	
	LOGGING_FACILITY(keyRef != NULL, @"keyRef object cannot be NULL." );
	
	NSMutableDictionary * queryKey = [[NSMutableDictionary alloc] init];
	
	// Set the PersistentKeyRef key query dictionary.
	[queryKey setObject:(id)keyRef forKey:(id)kSecValueRef];
	[queryKey setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnPersistentRef];
	
	// Get the persistent key reference.
	sanityCheck = SecItemCopyMatching((CFDictionaryRef)queryKey, (CFTypeRef *)&persistentRef);
	[queryKey release];
	
	return persistentRef;
}

- (SecCertificateRef)getCertificateRefWithPersistentCertificateRef:(CFTypeRef)persistentRef {
	OSStatus sanityCheck = noErr;
	SecCertificateRef certificateRef = NULL;
	
	LOGGING_FACILITY(persistentRef != NULL, @"persistentRef object cannot be NULL." );
	
	NSMutableDictionary * queryKey = [[NSMutableDictionary alloc] init];
	
	// Set the SecCertificateRef query dictionary.
	[queryKey setObject:(id)persistentRef forKey:(id)kSecValuePersistentRef];
	[queryKey setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnRef];
	
	// Get the persistent key reference.public
	sanityCheck = SecItemCopyMatching((CFDictionaryRef)queryKey, (CFTypeRef *)&certificateRef);
	[queryKey release];
	
	return certificateRef;
}


size_t encodeLength(unsigned char * buf, size_t length) {
    
    // encode length in ASN.1 DER format
    if (length < 128) {
        buf[0] = length;
        return 1;
    }
    
    size_t i = (length / 256) + 1;
    buf[0] = i + 0x80;
    for (size_t j = 0 ; j < i; ++j) {         buf[i - j] = length & 0xFF;         length = length >> 8;
    }
    
    return i + 1;
}

- (NSString *) getRSAPublicKeyAsBase64 {
    
    static const unsigned char _encodedRSAEncryptionOID[15] = {
        
        /* Sequence of length 0xd made up of OID followed by NULL */
        0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00
        
    };
    
    NSData * publicKeyBits=[self getPublicKeyBits];
    
    // OK - that gives us the "BITSTRING component of a full DER
    // encoded RSA public key - we now need to build the rest
    
    unsigned char builder[15];
    NSMutableData * encKey = [[NSMutableData alloc] init];
    int bitstringEncLength;
    
    // When we get to the bitstring - how will we encode it?
    if  ([publicKeyBits length ] + 1  < 128 )
        bitstringEncLength = 1 ;
    else
        bitstringEncLength = (([publicKeyBits length ] +1 ) / 256 ) + 2 ;
    
    // Overall we have a sequence of a certain length
    builder[0] = 0x30;    // ASN.1 encoding representing a SEQUENCE
    // Build up overall size made up of -
    // size of OID + size of bitstring encoding + size of actual key
    size_t i = sizeof(_encodedRSAEncryptionOID) + 2 + bitstringEncLength +
    [publicKeyBits length];
    size_t j = encodeLength(&builder[1], i);
    [encKey appendBytes:builder length:j +1];
    
    // First part of the sequence is the OID
    [encKey appendBytes:_encodedRSAEncryptionOID
                 length:sizeof(_encodedRSAEncryptionOID)];
    
    // Now add the bitstring
    builder[0] = 0x03;
    j = encodeLength(&builder[1], [publicKeyBits length] + 1);
    builder[j+1] = 0x00;
    [encKey appendBytes:builder length:j + 2];
    
    // Now the actual key
    [encKey appendData:publicKeyBits];
    
    // Now translate the result to a Base64 string
    
    NSString * ret =[encKey base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    [encKey release];
    return ret;
}

- (void)dealloc {
    [privateTag release];
    [publicTag release];
	[symmetricTag release];
	[symmetricKeyRef release];
	if (publicKeyRef) CFRelease(publicKeyRef);
	if (privateKeyRef) CFRelease(privateKeyRef);
    [super dealloc];
}

- (SecCertificateRef)getCertificate {
    OSStatus sanityCheck = noErr;
    SecCertificateRef certificateReference = NULL;
    
    if (privateKeyRef == NULL) {
        NSDictionary * queryCert = @{
            (id)kSecClass:                  (id)kSecClassCertificate,
            (id)kSecAttrLabel:              @CERT_TAG,
            (id)kSecReturnRef:              [NSNumber numberWithBool:YES],
            (id)kSecReturnPersistentRef:    [NSNumber numberWithBool:YES]
        };

        // Get the key.
        sanityCheck = SecItemCopyMatching((CFDictionaryRef)queryCert, (CFTypeRef *)&certificateReference);
        
        if (sanityCheck != noErr)
        {
            certificateReference = NULL;
        }
        
        [queryCert release];
    } else {
        certificateReference = certificateRef;
    }
    
    return certificateReference;
}

- (BOOL)generateCertificate {
    /*SCCSR * csr = [[SCCSR alloc] init];
    
    csr.commonName = @"inokiphone";
    csr.countryName = @"KDECnnectCountry";
    csr.organizationName = @"KDE";
    csr.organizationalUnitName = @"KDEConnect";
    csr.subjectDER = nil;
     */
    
    //certificate = [csr build:[self getPublicKeyBits] privateKey:[self getPrivateKeyRef]];
    //NSLog(@"Certificate: %@", certificate);
    
    //NSString *pem = @"MIIDJDCCAgwCCQDXNZ5EcwJADzANBgkqhkiG9w0BAQsFADBUMQwwCgYDVQQKDANLREUxEzARBgNVBAsMCktERUNvbm5lY3QxLzAtBgNVBAMMJl9hMjBlNTc5YV9jMWQ1XzRkMDlfODQyYl80MjQ1ZTRkMTM3OGJfMB4XDTE5MDgyMjE3MjQwNloXDTI5MDgxOTE3MjQwNlowVDEMMAoGA1UECgwDS0RFMRMwEQYDVQQLDApLREVDb25uZWN0MS8wLQYDVQQDDCZfYTIwZTU3OWFfYzFkNV80ZDA5Xzg0MmJfNDI0NWU0ZDEzNzhiXzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOQYgkZ04F6kx6Tc1+4ZP3Rr0vPzvRnXY6WeYD9c1EkIjxl/9XkGBGQ2yTq5kzio0DtlTbAPR3l1FYED8qNMwC+WRLPCaS2UPQ9emuPFj07+Dg1qgFyOL3pT26RenQpTB4LjzeXz9KdDB8LLxpaJzNxKM7ls7UdkiDNU/bfwa+T9g62JhGUXtMJUiU0nVR4xEu6fh46QvpPvJ0CvBSbodv+NnnfNm2yzpDqBf0bIlFgUwN/RqoW3u/KsZXnfRMHwxcwYY+4z4cGkRZxjnjAk3j8xqaJi1FHXPw7ONddDuo82Qd/qEX1fU7ZVQWgC1aXte2W1xPU98nVw5cQO8a80yjkCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEA3IFP7ideKNwNIZipd3wtkGBqGyr3WHwYGwzXoO/MooNToVZHzAcRQTZknqj6NvBgj8OpwxNkqUQJd0BIjQTxqDS9QCYlQ1QqngVvrCnE9SetgtTBsREj7Ki5LL9uurJUDJhq6mwk7x/+LLTmYURCvrr7bAgdzy2tyr5GNQOdDNy9TZxOH3ZeZ0uRf54qFTalu+3wDKSxsNvca/cLZiIv1H3Kvv8eP48vCnXQXaTuBKwKIjsqgppuzUqvAz4B5EEmyueZhM+KyhRB8yvaZcZI+LlgIps5zyi/t21gW6ha7lrcTA5NYUshrXwjjb5z936nX+cGhbFaE+P3H99PmnHB5Q==";
    
    NSData *privateKeyBits = [self getPrivateKeyBits];
    X509CertificateHelper *helper = [[X509CertificateHelper alloc] init];
    [helper generateX509Certificate: [privateKeyBits bytes] length: [privateKeyBits length]];
    [privateKeyBits release];
    [helper release];
    /*NSString *pem = @"MIICmDCCAYACAQAwUzEZMBcGA1UEBgwQS0RFQ25uZWN0Q291bnRyeTEMMAoGA1UECgwDS0RFMRMwEQYDVQQLDApLREVDb25uZWN0MRMwEQYDVQQDDAppbm9raXBob25lMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqIBtTdjLgqBJi2n2+tfFv0w6FT8OFyQ66mKBTv+Ah4HQB34MmjBTvoFUdGRavjELRqmqEPhmlxso5jMMp1eIVT6e/tP08bWTUzvMxQxVz3ELwLLOI2e0g8nb6qk+hiEX2SXdLosWw7Bn+WKUosltpfUIukJxz2RgLH+ygg7gqMzONI5yP/RyGRzC7Y0d2QiMkQ1rmYjOdAR5YS1wMDXiqIZ8ycs5LSyZAu2FEgotQbm8LLjoOn+t8mDPztvVwcE3h3m28eGFULKoLB8NaXqNI+kNwwSXsZe020FxwXpO6dwvbjCHQ1mqEpj/aQAYgJ2snh7yQ+M2POccxRaNbDdX1wIDAQABoAAwDQYJKoZIhvcNAQEFBQADggEBAD/MwPA3JN+iMJutweR7qR6PxrDnoPcA/gaIxXpysoaOPz1cQwG6DmfUxKa0cTARubC0o2DI65gafYaaeQ3qIWoc1JvcoJSsYNuz/oEzh1sN0ycasLaoc1hDxRZhmFIzAICcOPf12FP4h5Jz24i4rmfDeQ6U8izpa/Vb0kxV68upaVniiiugwi9xS8tZYktgpTL04V1ECh59ZqRpRIxwmWgtzltEUdJwjgxjZr6fEFRW7Do5XLcc8/tv6NEOrusPZPeLsadqj4FBAthnBe5U9fyjAM6ZIj73KOSLvDUEU9s6FQcqO7UfQzkl6931E3/vfN5njwZKOe2ffL8VeFXSItY=";

    // remove header, footer and newlines from pem string

    NSData *certData = [[NSData alloc] initWithBase64EncodedString: pem options: NSDataBase64DecodingIgnoreUnknownCharacters];
    
    NSLog(@"%@", certData);
    
    SecCertificateRef cert = SecCertificateCreateWithData(nil, (__bridge CFDataRef) certData);
    if( cert != NULL ) {
        CFStringRef certSummary = SecCertificateCopySubjectSummary(cert);
        NSString* summaryString = [[NSString alloc] initWithString:(__bridge NSString*)certSummary];
        NSLog(@"CERT SUMMARY: %@", summaryString);
        CFRelease(certSummary);
    } else {
        NSLog(@"1111 *** ERROR *** trying to create the SSL certificate from data, but failed");
    }
    
    NSDictionary *addquery = @{
        (id)kSecValueRef:   (__bridge id)cert,
        (id)kSecClass:      (id)kSecClassCertificate,
        (id)kSecAttrLabel:  @"kdeconnect_cert"
    };
    
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)addquery, NULL);
    if (status != errSecSuccess) {
        NSLog(@"Store not OK");
    } else {
        NSLog(@"Store OK");
    }
    
    NSMutableDictionary * certificateAttr = [[NSMutableDictionary alloc] init];
    /*
     attributes
     A dictionary that describes the item to add. A typical attributes dictionary consists of:

     The item's class. Different attributes and behaviors apply to different classes of items. You use the kSecClass key with a suitable value to tell keychain services whether the data you want to store represents a password, a certificate, a cryptographic key, or something else. See Item Class Keys and Values.

     The data. Use the kSecValueData key to indicate the data you want to store. Keychain services takes care of encrypting this data if the item is secret, namely when it’s one of the password types or involves a private key.

     Optional attributes. Include attribute keys that allow you to find the item later and that indicate how the data should be used or shared. You may add any number of attributes, although many are specific to a particular class of item. See Item Attribute Keys and Values for the complete list.

     Optional return types. Include one or more return type keys to indicate what data, if any, you want returned upon successful completion. You often ignore the return data from a SecItemAdd call, in which case no return value key is needed. See Item Return Result Keys for more information.

     result
     On return, a reference to the newly added items. The exact type of the result is based on the values supplied in attributes, as discussed in Item Return Result Keys. Pass nil if you don’t need the result. Otherwise, your app becomes responsible for releasing the referenced object.
     */
    /*
    OSStatus sanityCheck = noErr;
    
    
    // https://en.it1352.com/article/24487823a1f24d32b75b08549abbc0df.html
   /* SecCertificateRef _certificate = SecCertificateCreateWithData(kCFAllocatorMalloc, (__bridge CFDataRef)certificate);
    //LOGGING_FACILITY1( _certificate!=NULL, @"Error create cert %@", _certificate);
    if( _certificate != NULL ) {
        CFStringRef certSummary = SecCertificateCopySubjectSummary(_certificate);
        NSString* summaryString = [[NSString alloc] initWithString:(__bridge NSString*)certSummary];
        NSLog(@"CERT SUMMARY: %@", summaryString);
        CFRelease(certSummary);
    } else {
        NSLog(@" *** ERROR *** trying to create the SSL certificate from data, but failed");
    }
    */
    /*[certificateAttr setObject:(id)kSecClassCertificate forKey:(id)kSecClass];
    [certificateAttr setObject:(id)cert forKey:(id)kSecValueData];
    [certificateAttr setObject:(id)kSecAttrAccessibleAlwaysThisDeviceOnly forKey:(id)kSecAttrAccessible];
    [certificateAttr setObject:(id)@"kdeconnect_cert" forKey:(id)kSecAttrLabel];
    
    sanityCheck = SecItemAdd((CFDictionaryRef)certificateAttr, NULL);
    */
//LOGGING_FACILITY1( sanityCheck == noErr, @"Error adding certificate, OSStatus == %d.", sanityCheck );
    //[certificateAttr release];
    
    //[csr release];
    return YES;
}
#endif

@end
