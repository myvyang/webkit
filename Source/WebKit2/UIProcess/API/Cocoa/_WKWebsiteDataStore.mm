/*
 * Copyright (C) 2014 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "config.h"
#import "_WKWebsiteDataStoreInternal.h"

#if WK_API_ENABLED

#import "APIArray.h"
#import "WKNSArray.h"
#import "_WKWebsiteDataRecordInternal.h"

@implementation _WKWebsiteDataStore

+ (instancetype)defaultDataStore
{
    return WebKit::wrapper(*API::WebsiteDataStore::defaultDataStore().get());
}

+ (instancetype)nonPersistentDataStore
{
    return [WebKit::wrapper(*API::WebsiteDataStore::createNonPersistentDataStore().release().leakRef()) autorelease];
}

- (void)dealloc
{
    _websiteDataStore->API::WebsiteDataStore::~WebsiteDataStore();

    [super dealloc];
}

- (BOOL)isNonPersistent
{
    return _websiteDataStore->isNonPersistent();
}

static std::chrono::system_clock::time_point toSystemClockTime(NSDate *date)
{
    ASSERT(date);
    using namespace std::chrono;

    return system_clock::time_point(duration_cast<system_clock::duration>(duration<double>(date.timeIntervalSince1970)));
}

- (void)fetchDataRecordsOfTypes:(WKWebsiteDataTypes)websiteDataTypes completionHandler:(void (^)(NSArray *))completionHandler
{
    auto completionHandlerCopy = Block_copy(completionHandler);

    _websiteDataStore->websiteDataStore().fetchData(WebKit::toWebsiteDataTypes(websiteDataTypes), [completionHandlerCopy](Vector<WebKit::WebsiteDataRecord> websiteDataRecords) {
        Vector<RefPtr<API::Object>> elements;
        elements.reserveInitialCapacity(websiteDataRecords.size());

        for (auto& websiteDataRecord : websiteDataRecords)
            elements.uncheckedAppend(API::WebsiteDataRecord::create(WTF::move(websiteDataRecord)));

        completionHandlerCopy(wrapper(*API::Array::create(WTF::move(elements))));

        Block_release(completionHandlerCopy);
    });
}

- (void)removeDataOfTypes:(WKWebsiteDataTypes)websiteDataTypes modifiedSince:(NSDate *)date completionHandler:(void (^)())completionHandler
{
    auto completionHandlerCopy = Block_copy(completionHandler);
    _websiteDataStore->websiteDataStore().removeData(WebKit::toWebsiteDataTypes(websiteDataTypes), toSystemClockTime(date ? date : [NSDate distantPast]), [completionHandlerCopy] {
        completionHandlerCopy();
        Block_release(completionHandlerCopy);
    });
}

static Vector<WebKit::WebsiteDataRecord> toWebsiteDataRecords(NSArray *dataRecords)
{
    Vector<WebKit::WebsiteDataRecord> result;

    for (_WKWebsiteDataRecord *dataRecord in dataRecords)
        result.append(dataRecord->_websiteDataRecord->websiteDataRecord());

    return result;
}

- (void)removeDataOfTypes:(WKWebsiteDataTypes)websiteDataTypes forDataRecords:(NSArray *)dataRecords completionHandler:(void (^)())completionHandler
{
    auto completionHandlerCopy = Block_copy(completionHandler);

    _websiteDataStore->websiteDataStore().removeData(WebKit::toWebsiteDataTypes(websiteDataTypes), toWebsiteDataRecords(dataRecords), [completionHandlerCopy] {
        completionHandlerCopy();
        Block_release(completionHandlerCopy);
    });
}

#pragma mark WKObject protocol implementation

- (API::Object&)_apiObject
{
    return *_websiteDataStore;
}

@end

#endif // WK_API_ENABLED
