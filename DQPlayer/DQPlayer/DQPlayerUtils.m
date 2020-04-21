//
//  DQPlayerUtils.m
//  DQPlayer
//
//  Created by dqfeng on 2019/1/17.
//  Copyright © 2019年 appfactory. All rights reserved.
//

#import "DQPlayerUtils.h"
#import <CommonCrypto/CommonDigest.h>
#import <MobileCoreServices/MobileCoreServices.h>

static NSString *const kDQPlayerSupportUrlSchemeSuffix = @"-stream";
NSString *const kDQPlayerCacheSubDirectoryName = @"DQPlayerCache";
const NSRange DQInvalidRange = {NSNotFound,0};


@implementation DQPlayerUtils

+ (long long)fileLengthOfHTTPURLResponse:(NSHTTPURLResponse *)httpUrlResponse
{
    NSString *range = [httpUrlResponse allHeaderFields][@"Content-Range"];
    if (range) {
        NSArray *ranges = [range componentsSeparatedByString:@"/"];
        if (ranges.count > 0) {
            NSString *lengthString = [[ranges lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            return [lengthString longLongValue];
        }
    }
    else {
        return [httpUrlResponse expectedContentLength];
    }
    return 0;

}

+ (BOOL)isSupportRangeOfHTTPURLResponse:(NSHTTPURLResponse *)httpUrlResponse;
{
    return [httpUrlResponse allHeaderFields][@"Content-Range"] != nil;
}

+ (void)avAssetResourceLoadingRequest:(AVAssetResourceLoadingRequest *)request fillContentInformation:(NSHTTPURLResponse *)response
{
    if (!response) {
        return;
    }
    
    request.response = response;
    
    if (!request.contentInformationRequest) {
        return;
    }
    
    NSString *mimeType = [response MIMEType];
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    request.contentInformationRequest.byteRangeAccessSupported = [self isSupportRangeOfHTTPURLResponse:response];
    request.contentInformationRequest.contentType = CFBridgingRelease(contentType);
    request.contentInformationRequest.contentLength = [self fileLengthOfHTTPURLResponse:response];
}

+ (BOOL)fileHandle:(NSFileHandle *)fileHandle safeWriteData:(NSData *)data
{
    NSInteger retry = 3;
    size_t bytesLeft = data.length;
    const void *bytes = [data bytes];
    int fileDescriptor = [fileHandle fileDescriptor];
    while (bytesLeft > 0 && retry > 0) {
        ssize_t amountSent = write(fileDescriptor, bytes + data.length - bytesLeft, bytesLeft);
        if (amountSent < 0) {
            //write failed
            break;
        }
        else {
            bytesLeft = bytesLeft - amountSent;
            if (bytesLeft > 0) {
                //not finished continue write after sleep 1 second
                sleep(1);  //probably too long, but this is quite rare
                retry--;
            }
        }
    }
    return bytesLeft == 0;
}

+ (NSRange)rangeOfURLRequest:(NSURLRequest *)request
{
    NSRange range = NSMakeRange(NSNotFound, 0);
    NSString *rangeString = [request allHTTPHeaderFields][@"Range"];
    if ([rangeString hasPrefix:@"bytes="]) {
        NSArray* components = [[rangeString substringFromIndex:6] componentsSeparatedByString:@","];
        if (components.count == 1) {
            components = [[components firstObject] componentsSeparatedByString:@"-"];
            if (components.count == 2) {
                NSString* startString = [components objectAtIndex:0];
                NSInteger startValue = [startString integerValue];
                NSString* endString = [components objectAtIndex:1];
                NSInteger endValue = [endString integerValue];
                if (startString.length && (startValue >= 0) && endString.length && (endValue >= startValue)) {
                    // The second 500 bytes: "500-999"
                        range.location = startValue;
                        range.length = endValue - startValue + 1;
                }
                else if (startString.length && (startValue >= 0)) {
                    // The bytes after 9500 bytes: "9500-"
                        range.location = startValue;
                        range.length = NSUIntegerMax;
                }
                else if (endString.length && (endValue > 0)){
                    // The final 500 bytes: "-500"
                        range.location = NSNotFound;
                        range.length = endValue;
                }
            }
        }
    }
    return range;
}

+ (NSString *)md5OfString:(NSString *)string
{
    const char *cStr = [string UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (int)strlen(cStr), result ); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

+ (NSURL *)URL:(NSURL *)url byReplacingSchemeWithString:(NSString *)scheme
{
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
    components.scheme = scheme;
    return components.URL;
}

+ (NSURL *)cacheSupportURLFromURL:(NSURL *)url
{
    if (![self isCacheSupportOfURL:url]) {
        NSString *scheme = [[url scheme] stringByAppendingString:kDQPlayerSupportUrlSchemeSuffix];
        return [self URL:url byReplacingSchemeWithString:scheme];
    }
    return url;
}

+ (NSURL *)originalURLFromCacheSupportURL:(NSURL *)url
{
    if ([self isCacheSupportOfURL:url]) {
        NSString *scheme = [[url scheme] stringByReplacingOccurrencesOfString:kDQPlayerSupportUrlSchemeSuffix withString:@""];
        return [self URL:url byReplacingSchemeWithString:scheme];
    }
    return url;
}

+ (BOOL)isCacheSupportOfURL:(NSURL *)url
{
    return [[url scheme] hasSuffix:kDQPlayerSupportUrlSchemeSuffix];
}

+ (NSString *)URL:(NSURL *)url pathComponentRelativeToURL:(NSURL *)baseURL
{
    NSString *absoluteString = [url absoluteString];
    NSString *baseURLString = [baseURL absoluteString];
    NSRange range = [absoluteString rangeOfString:baseURLString];
    if (range.location == 0) {
        NSString *subString = [absoluteString substringFromIndex:range.location + range.length];
        return subString;
    }
    return nil;
}

+ (BOOL)isM3UOfURL:(NSURL *)url
{
    return [[[url pathExtension] lowercaseString] hasPrefix:@"m3u"];
}

+ (BOOL)isM3UOfUrlString:(NSString *)urlString
{
    return [[[urlString pathExtension] lowercaseString] hasPrefix:@"m3u"];
}

@end
