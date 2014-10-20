//
//  HttpManager.m
//  Limelight
//
//  Created by Diego Waxemberg on 10/16/14.
//  Copyright (c) 2014 Limelight Stream. All rights reserved.
//

#import "HttpManager.h"
#import "CryptoManager.h"

#include <libxml2/libxml/xmlreader.h>
#include <string.h>

@implementation HttpManager {
    NSString* _baseURL;
    NSString* _host;
    NSString* _uniqueId;
    NSString* _deviceName;
    NSData* _cert;
    NSMutableData* _respData;
    NSData* _requestResp;
    dispatch_semaphore_t _requestLock;
}

static const NSString* PORT = @"47984";

+ (NSString*) getStringFromXML:(NSData*)xml tag:(NSString*)tag {
    xmlDocPtr docPtr = xmlParseMemory([xml bytes], [xml length]);
    
    if (docPtr == NULL) {
        NSLog(@"ERROR: An error occured trying to parse xml.");
        return NULL;
    }
    NSString* value;
    xmlNodePtr node;
    xmlNodePtr rootNode = node = xmlDocGetRootElement(docPtr);
    
    // Check root status_code
    if (![HttpManager verifyStatus: rootNode]) {
        //TODO: handle error
    }
    
    // Skip the root node
    node = node->children;
    
    while (node != NULL) {
        //NSLog(@"node: %s", node->name);
        if (!xmlStrcmp(node->name, (const xmlChar*)[tag UTF8String])) {
            xmlChar* nodeVal = xmlNodeListGetString(docPtr, node->xmlChildrenNode, 1);
            value = [[NSString alloc] initWithCString:(const char*)nodeVal encoding:NSUTF8StringEncoding];
            xmlFree(nodeVal);
        }
        node = node->next;
    }
    //NSLog(@"xmlValue: %@", value);
    xmlFree(rootNode);
    xmlFree(docPtr);
    
    return value;
}

+ (bool) verifyStatus:(xmlNodePtr)docRoot {
    xmlChar* statusStr = xmlGetProp(docRoot, (const xmlChar*)"status_code");
    NSLog(@"status: %s", statusStr);
    int status = [[NSString stringWithUTF8String:(const char*)statusStr] intValue];
    xmlFree(statusStr);
    return status == 200;
}

+ (NSData*) fixXmlVersion:(NSData*) xmlData {
    NSString* xmlString = [[[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"UTF-16" withString:@"UTF-8" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [xmlData length])];
    //NSLog(@"xmlString: %@", xmlString);
    return [NSData dataWithBytes:[xmlString UTF8String] length:[xmlString length]];
}

- (id) initWithHost:(NSString*) host uniqueId:(NSString*) uniqueId deviceName:(NSString*) deviceName cert:(NSData*) cert {
    self = [super init];
    _host = host;
    _uniqueId = uniqueId;
    _deviceName = deviceName;
    _cert = cert;
    _baseURL = [[NSString stringWithFormat:@"https://%@:%@", host, PORT]
                stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    _requestLock = dispatch_semaphore_create(0);
    _respData = [[NSMutableData alloc] init];
    return self;
}

- (NSData*) executeRequestSynchronously:(NSURLRequest*)request {
    NSLog(@"Making Request: %@", request);
    [_respData setLength:0];
    dispatch_sync(dispatch_get_main_queue(), ^{
        [NSURLConnection connectionWithRequest:request delegate:self];
    });
    dispatch_semaphore_wait(_requestLock, DISPATCH_TIME_FOREVER);
    return _requestResp;
}

- (void) executeRequest:(NSURLRequest*)request {
    [NSURLConnection connectionWithRequest:request delegate:self];
}

- (NSURLRequest*) createRequestFromString:(NSString*) urlString {
    NSString* escapedUrl = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL* url = [[NSURL alloc] initWithString:escapedUrl];
    return [NSURLRequest requestWithURL:url];
}

- (NSURLRequest*) newPairRequest:(NSData*)salt {
    NSString* urlString = [NSString stringWithFormat:@"%@/pair?uniqueid=%@&devicename=%@&updateState=1&phrase=getservercert&salt=%@&clientcert=%@",
                           _baseURL, _uniqueId, _deviceName, [self bytesToHex:salt], [self bytesToHex:_cert]];
    return [self createRequestFromString:urlString];
}

- (NSURLRequest*) newUnpairRequest {
    NSString* urlString = [NSString stringWithFormat:@"%@/unpair?uniqueid=%@", _baseURL, _uniqueId];
    return [self createRequestFromString:urlString];
}

- (NSURLRequest*) newChallengeRequest:(NSData*)challenge {
    NSString* urlString = [NSString stringWithFormat:@"%@/pair?uniqueid=%@&devicename=%@&updateState=1&clientchallenge=%@",
                           _baseURL, _uniqueId, _deviceName, [self bytesToHex:challenge]];
    return [self createRequestFromString:urlString];
}

- (NSURLRequest*) newChallengeRespRequest:(NSData*)challengeResp {
    NSString* urlString = [NSString stringWithFormat:@"%@/pair?uniqueid=%@&devicename=%@&updateState=1&serverchallengeresp=%@",
                           _baseURL, _uniqueId, _deviceName, [self bytesToHex:challengeResp]];
    return [self createRequestFromString:urlString];
}

- (NSURLRequest*) newClientSecretRespRequest:(NSString*)clientPairSecret {
    NSString* urlString = [NSString stringWithFormat:@"%@/pair?uniqueid=%@&devicename=%@&updateState=1&clientpairingsecret=%@", _baseURL, _uniqueId, _deviceName, clientPairSecret];
    return [self createRequestFromString:urlString];
}

- (NSURLRequest*) newPairChallenge {
    NSString* urlString = [NSString stringWithFormat:@"%@/pair?uniqueid=%@&devicename=%@&updateState=1&phrase=pairchallenge", _baseURL, _uniqueId, _deviceName];
    return [self createRequestFromString:urlString];
}

- (NSURLRequest *)newAppListRequest {
    NSString* urlString = [NSString stringWithFormat:@"%@/applist?uniqueid=%@", _baseURL, _uniqueId];
    return [self createRequestFromString:urlString];
}

- (NSURLRequest *)newServerInfoRequest {
    NSString* urlString = [NSString stringWithFormat:@"%@/serverinfo?uniqueid=%@", _baseURL, _uniqueId];
    return [self createRequestFromString:urlString];
}

- (NSURLRequest*) newLaunchRequest:(NSString*)appId width:(int)width height:(int)height refreshRate:(int)refreshRate rikey:(NSString*)rikey rikeyid:(int)rikeyid {
    NSString* urlString = [NSString stringWithFormat:@"%@/launch?uniqueid=%@&appid=%@&mode=%dx%dx%d&additionalStates=1&sops=1&rikey=%@&rikeyid=%d", _baseURL, _uniqueId, appId, width, height, refreshRate, rikey, rikeyid];
    return [self createRequestFromString:urlString];
}

- (NSString*) bytesToHex:(NSData*)data {
    const unsigned char* bytes = [data bytes];
    NSMutableString *hex = [[NSMutableString alloc] init];
    for (int i = 0; i < [data length]; i++) {
        [hex appendFormat:@"%02X" , bytes[i]];
    }
    return hex;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSLog(@"Received response: %@", response);
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    NSLog(@"Received data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    [_respData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    _requestResp = [HttpManager fixXmlVersion:_respData];
    dispatch_semaphore_signal(_requestLock);
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    SecIdentityRef identity = [self getClientCertificate];  // Go get a SecIdentityRef
    CFArrayRef certs = [self getCertificate:identity]; // Get an array of certificates
    NSArray *certArray = (__bridge NSArray *)certs;
    
    NSURLCredential *newCredential = [NSURLCredential credentialWithIdentity:identity certificates:certArray persistence:NSURLCredentialPersistencePermanent];
    
    [challenge.sender useCredential:newCredential forAuthenticationChallenge:challenge];
}

// Returns an array containing the certificate
- (CFArrayRef)getCertificate:(SecIdentityRef) identity {
    SecCertificateRef certificate = nil;
    
    SecIdentityCopyCertificate(identity, &certificate);
    SecCertificateRef certs[1] = { certificate };
    
    CFArrayRef certArray = CFArrayCreate(NULL, (const void **) certs, 1, NULL);
    
    SecPolicyRef policyRef   = SecPolicyCreateBasicX509();
    SecTrustRef trustRef;
    
    OSStatus status = SecTrustCreateWithCertificates(certArray, policyRef, &trustRef);
    if (status != noErr) {
        NSLog(@"Error Creating certificate");
    }
    return certArray;
}

// Returns the identity
- (SecIdentityRef)getClientCertificate {
    SecIdentityRef identityApp = nil;
    CFDataRef p12Data = (__bridge CFDataRef)[CryptoManager readP12FromFile];

    CFStringRef password = CFSTR("limelight");
    const void *keys[] = { kSecImportExportPassphrase };
    const void *values[] = { password };
    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);
    OSStatus securityError = SecPKCS12Import(p12Data, options, &items);

    if (securityError == errSecSuccess) {
        //NSLog(@"Success opening p12 certificate. Items: %ld", CFArrayGetCount(items));
        CFDictionaryRef identityDict = CFArrayGetValueAtIndex(items, 0);
        identityApp = (SecIdentityRef)CFDictionaryGetValue(identityDict, kSecImportItemIdentity);
    } else {
        NSLog(@"Error opening Certificate.");
    }
    
    CFRelease(options);
    CFRelease(password);
    
    return identityApp;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"connection error: %@", error);
}

@end
