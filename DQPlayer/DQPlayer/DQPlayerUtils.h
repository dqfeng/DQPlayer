//
//  DQPlayerUtils.h
//  DQPlayer
//
//  Created by dqfeng on 2019/1/17.
//  Copyright © 2019年 appfactory. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVAssetResourceLoader.h>

FOUNDATION_EXTERN const NSRange DQInvalidRange;
FOUNDATION_EXTERN NSString *const kDQPlayerCacheSubDirectoryName;

NS_INLINE BOOL DQValidByteRange(NSRange range)
{
    return ((range.location != NSNotFound) || (range.length > 0));
}

NS_INLINE BOOL DQValidFileRange(NSRange range)
{
    return ((range.location != NSNotFound) && range.length > 0 && range.length != NSUIntegerMax);
}

NS_INLINE BOOL DQRangeCanMerge(NSRange range1,NSRange range2)
{
    return (NSMaxRange(range1) == range2.location) || (NSMaxRange(range2) == range1.location) || NSIntersectionRange(range1, range2).length > 0;
}

NS_INLINE NSString* DQRangeToHTTPRangeHeader(NSRange range)
{
    if (DQValidByteRange(range)) {
        if (range.location == NSNotFound) {
            return [NSString stringWithFormat:@"bytes=-%tu",range.length];
        }
        else if (range.length == NSUIntegerMax) {
            return [NSString stringWithFormat:@"bytes=%tu-",range.location];
        }
        else {
            return [NSString stringWithFormat:@"bytes=%tu-%tu",range.location, NSMaxRange(range) - 1];
        }
    }
    else {
        return nil;
    }
}

NS_INLINE NSString* DQRangeToHTTPRangeReponseHeader(NSRange range,NSUInteger length)
{
    if (DQValidByteRange(range)) {
        NSUInteger start = range.location;
        NSUInteger end = NSMaxRange(range) - 1;
        if (range.location == NSNotFound) {
            start = range.location;
        }
        else if (range.length == NSUIntegerMax) {
            start = length - range.length;
            end = start + range.length - 1;
        }
        return [NSString stringWithFormat:@"bytes %tu-%tu/%tu",start,end,length];
    }
    else {
        return nil;
    }
}

@interface DQPlayerUtils : NSObject

+ (long long)fileLengthOfHTTPURLResponse:(NSHTTPURLResponse *)httpUrlResponse;
+ (BOOL)isSupportRangeOfHTTPURLResponse:(NSHTTPURLResponse *)httpUrlResponse;
+ (void)avAssetResourceLoadingRequest:(AVAssetResourceLoadingRequest *)request fillContentInformation:(NSHTTPURLResponse *)response;
+ (BOOL)fileHandle:(NSFileHandle *)fileHandle safeWriteData:(NSData *)data;
+ (NSRange)rangeOfURLRequest:(NSURLRequest *)request;
+ (NSString *)md5OfString:(NSString *)string;
+ (NSURL *)URL:(NSURL *)url byReplacingSchemeWithString:(NSString *)scheme;
+ (NSURL *)cacheSupportURLFromURL:(NSURL *)url;
+ (NSURL *)originalURLFromCacheSupportURL:(NSURL *)url;
+ (BOOL)isCacheSupportOfURL:(NSURL *)url;
+ (NSString *)URL:(NSURL *)url pathComponentRelativeToURL:(NSURL *)baseURL;
+ (BOOL)isM3UOfURL:(NSURL *)url;
+ (BOOL)isM3UOfUrlString:(NSString *)urlString;

@end

