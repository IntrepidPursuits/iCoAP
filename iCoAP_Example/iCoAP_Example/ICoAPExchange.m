//
//  ICoAPExchange.m
//  iCoAP
//
//  Created by Wojtek Kordylewski on 25.06.13.


#import "ICoAPExchange.h"
#import "NSString+hex.h"

@implementation ICoAPExchange

#pragma mark - Init

- (id)init {
    if (self = [super init]) {
        randomMessageId = 1 + arc4random() % 65536;
        randomToken = 1 + arc4random() % INT_MAX;
        supportedOptions = @[
                             @(IC_IF_MATCH),
                             @(IC_URI_HOST),
                             @(IC_ETAG),
                             @(IC_IF_NONE_MATCH),
                             @(IC_OBSERVE),
                             @(IC_URI_PORT),
                             @(IC_LOCATION_PATH),
                             @(IC_URI_PATH),
                             @(IC_CONTENT_FORMAT),
                             @(IC_MAX_AGE),
                             @(IC_URI_QUERY),
                             @(IC_ACCEPT),
                             @(IC_LOCATION_QUERY),
                             @(IC_BLOCK2),
                             @(IC_BLOCK1),
                             @(IC_SIZE2),
                             @(IC_PROXY_URI),
                             @(IC_PROXY_SCHEME),
                             @(IC_SIZE1),
                             ];
    }
    return self;
}

- (id)initAndSendRequestWithCoAPMessage:(ICoAPMessage *)message toHost:(NSString* )host port:(uint)port delegate:(id)delegate {
    if (self = [self init]) {
        self.delegate = delegate;
        [self sendRequestWithCoAPMessage:message toHost:host port:port];
    }
    return self;
}

- (BOOL)setupUdpSocket {
    self.udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    NSError *error;
    if (![self.udpSocket bindToPort:self.udpPort error:&error]) {
        return NO;
    }
    
    if (![self.udpSocket beginReceiving:&error]) {
        [self.udpSocket close];
        return NO;
    }
    return YES;
}

#pragma mark - GCD Async UDP Socket Delegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    
    ICoAPMessage *message = [[ICoAPMessage alloc] initWithData:data];
    
    //Check if received data is a valid CoAP Message
    if (!message) {
        return;
    }

    //Set Timestamp
    message.timestamp = [[NSDate alloc] init];
    
    //Check for spam and if Observe is Cancelled
    if ((message.messageID != pendingCoAPMessageInTransmission.messageID && message.token != pendingCoAPMessageInTransmission.token) || ([message.optionDict valueForKey:[NSString stringWithFormat:@"%i", IC_OBSERVE]] && isObserveCancelled && message.type != IC_ACKNOWLEDGMENT)) {
        if (message.type <= IC_NON_CONFIRMABLE) {
            [self sendCircumstantialResponseWithMessageID:message.messageID type:IC_RESET toAddress:address];
        }
        return;
    }
    
    //Invalidate Timers: Resend- and Max-Wait Timer
    if (message.type == IC_ACKNOWLEDGMENT || message.type == IC_RESET || message.type == IC_NON_CONFIRMABLE) {
        [sendTimer invalidate];
        [maxWaitTimer invalidate];
    }

    if (!(message.type == IC_ACKNOWLEDGMENT && message.code == IC_EMPTY) && !([message.optionDict valueForKey:[NSString stringWithFormat:@"%i", IC_BLOCK2]] && ![message.optionDict valueForKey:[NSString stringWithFormat:@"%i", IC_OBSERVE]])) {
        _isMessageInTransmission = NO;
    }
    
    //Separate Response / Observe: Send ACK
    if (message.type == IC_CONFIRMABLE) {        
        [self sendCircumstantialResponseWithMessageID:message.messageID type:IC_ACKNOWLEDGMENT toAddress:address];
    }
    
    //Block Options: Only send a Block2 request when observe option is inactive:
    if ([message.optionDict valueForKey:[NSString stringWithFormat:@"%i", IC_BLOCK2]] && ![message.optionDict valueForKey:[NSString stringWithFormat:@"%i", IC_OBSERVE]]) {
        [self handleBlock2OptionForCoapMessage:message];
    }
    
    //Check for Observe Option: If Observe Option is present, the message is only sent to the delegate if the order is correct.
    if ([message.optionDict valueForKey:[NSString stringWithFormat:@"%i", IC_OBSERVE]] && message.type != IC_ACKNOWLEDGMENT) {
        uint currentObserveValue = [[[message.optionDict valueForKey:[NSString stringWithFormat:@"%i", IC_OBSERVE]] objectAtIndex:0] intValue];
       
        if (!recentNotificationDate) {
            recentNotificationDate = [[NSDate alloc] init];
        }
        
        recentNotificationDate = [recentNotificationDate dateByAddingTimeInterval:kMaxNotificationDelayTime];
        
        if ((observeOptionValue < currentObserveValue && currentObserveValue - observeOptionValue < kMaxObserveOptionValue) ||
            (observeOptionValue > currentObserveValue && observeOptionValue - currentObserveValue > kMaxObserveOptionValue) ||
            [recentNotificationDate compare:message.timestamp] == NSOrderedAscending) {
            
            recentNotificationDate = message.timestamp;
            observeOptionValue = currentObserveValue;
        }
        else {
            return;
        }
    }
    
    [self sendDidReceiveMessageToDelegateWithCoAPMessage:message];
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
    [self closeExchange];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"UDP Socket could not send data." forKey:NSLocalizedDescriptionKey];
    [self sendFailWithErrorToDelegateWithError:[[NSError alloc] initWithDomain:kiCoAPErrorDomain code:IC_UDP_SOCKET_ERROR userInfo:userInfo]];
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    [self closeExchange];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"UDP Socket Closed" forKey:NSLocalizedDescriptionKey];
    [self sendFailWithErrorToDelegateWithError:[[NSError alloc] initWithDomain:kiCoAPErrorDomain code:IC_UDP_SOCKET_ERROR userInfo:userInfo]];
}

#pragma mark - Delegate Method Calls

- (void)noResponseExpected {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"No Response expected for recently sent CoAP Message" forKey:NSLocalizedDescriptionKey];

    [self sendFailWithErrorToDelegateWithError:[[NSError alloc] initWithDomain:kiCoAPErrorDomain code:IC_RESPONSE_TIMEOUT userInfo:userInfo]];
    [self closeExchange];
}

- (void)sendDidReceiveMessageToDelegateWithCoAPMessage:(ICoAPMessage *)coapMessage {
    if ([self.delegate respondsToSelector:@selector(iCoAPExchange:didReceiveCoAPMessage:)]) {
        [self.delegate iCoAPExchange:self didReceiveCoAPMessage:coapMessage];
    }
}

- (void)sendDidRetransmitMessageToDelegateWithCoAPMessage:(ICoAPMessage *)coapMessage {
    if ([self.delegate respondsToSelector:@selector(iCoAPExchange:didRetransmitCoAPMessage:number:finalRetransmission:)]) {
        retransmissionCounter == kMAX_RETRANSMIT ?
        [self.delegate iCoAPExchange:self didRetransmitCoAPMessage:pendingCoAPMessageInTransmission number:retransmissionCounter finalRetransmission:YES] :
        [self.delegate iCoAPExchange:self didRetransmitCoAPMessage:pendingCoAPMessageInTransmission number:retransmissionCounter finalRetransmission:NO];
    }
}

- (void)sendFailWithErrorToDelegateWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(iCoAPExchange:didFailWithError:)]) {
        [self.delegate iCoAPExchange:self didFailWithError:error];
    }
}

#pragma mark - Other Methods

- (void)handleBlock2OptionForCoapMessage:(ICoAPMessage *)message {
    NSString *blockValue = [NSString stringWithFormat:@"%02X", [[[message.optionDict valueForKey:[NSString stringWithFormat:@"%i", IC_BLOCK2]] objectAtIndex:0] intValue]];
    
    uint blockNum = (uint)strtol([[blockValue substringToIndex:[blockValue length] - 1] UTF8String], NULL, 16);
    uint blockTail = (uint)strtol([[blockValue substringFromIndex:[blockValue length] - 1] UTF8String], NULL, 16);
    
    if (blockTail > 7) {
        //More Flag is set
        ICoAPMessage *blockObject = [[ICoAPMessage alloc] init];
        blockObject.isRequest = YES;
        blockObject.type = IC_CONFIRMABLE;
        blockObject.code = pendingCoAPMessageInTransmission.code;
        blockObject.messageID = pendingCoAPMessageInTransmission.messageID + 1 % 65536;
        randomMessageId++;
        blockObject.token = pendingCoAPMessageInTransmission.token;
        blockObject.host = pendingCoAPMessageInTransmission.host;
        blockObject.port = pendingCoAPMessageInTransmission.port;
        blockObject.httpProxyHost = pendingCoAPMessageInTransmission.httpProxyHost;
        blockObject.httpProxyPort = pendingCoAPMessageInTransmission.httpProxyPort;
        blockObject.optionDict =  [[NSMutableDictionary alloc] init];
        for (id key in pendingCoAPMessageInTransmission.optionDict) {
            if (![key isEqualToString:[NSString stringWithFormat:@"%i", IC_BLOCK2]]) {
                [blockObject.optionDict setValue:[[NSMutableArray alloc] initWithArray:[pendingCoAPMessageInTransmission.optionDict valueForKey:key]] forKey:key];
            }
        }
        
        NSString *newBlockValue = [NSString stringWithFormat:@"%i", (blockNum + 1) * 16 + blockTail - 8];
        [blockObject addOption:IC_BLOCK2 withValue:newBlockValue];
        
        pendingCoAPMessageInTransmission = blockObject;
        if (message.usesHttpProxying) {
            [self sendHttpMessageFromCoAPMessage:pendingCoAPMessageInTransmission];
        }
        else {
            [self startSending];
        }
    }
    else {
        _isMessageInTransmission = NO;
    }
}



- (void)cancelObserve {
    isObserveCancelled = YES;
}

#pragma mark - Send Methods

- (void)sendCircumstantialResponseWithMessageID:(uint)messageID type:(ICoAPType)type toAddress:(NSData *)address {
    ICoAPMessage *ackObject = [[ICoAPMessage alloc] init];
    ackObject.isRequest = NO;
    ackObject.type = type;
    ackObject.messageID = messageID;
    
    [self.udpSocket sendData:[ackObject data] toAddress:address withTimeout:-1 tag:udpSocketTag];
    udpSocketTag++;
}

- (void)sendRequestWithCoAPMessage:(ICoAPMessage *)message toHost:(NSString *)host port:(uint)port {
    randomMessageId++;
    randomToken++;
    
    message.messageID = randomMessageId % 65536;
    
    if ([message isTokenRequested]) {
        message.token = randomToken % INT_MAX;
    }
    
    message.isRequest = YES;
    message.host = host;
    message.port = port;
    pendingCoAPMessageInTransmission = message;
    pendingCoAPMessageInTransmission.timestamp = [[NSDate alloc] init];

    if (message.usesHttpProxying) {
        [self sendHttpMessageFromCoAPMessage:pendingCoAPMessageInTransmission];
    }
    else {
        if (!self.udpSocket && ![self setupUdpSocket]) {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Failed to setup UDP Socket" forKey:NSLocalizedDescriptionKey];
            
            [self sendFailWithErrorToDelegateWithError:[[NSError alloc] initWithDomain:kiCoAPErrorDomain code:IC_UDP_SOCKET_ERROR userInfo:userInfo]];
            return;
        }
        
        [self startSending];
    }
}

- (void)startSending {
    [self resetState];
    
    if (pendingCoAPMessageInTransmission.type == IC_CONFIRMABLE) {
        retransmissionCounter = 0;
        maxWaitTimer = [NSTimer scheduledTimerWithTimeInterval:kMAX_TRANSMIT_WAIT target:self selector:@selector(noResponseExpected) userInfo:nil repeats:NO];
        
        [self performTransmissionCycle];
    }
    else {
        [self sendCoAPMessage];
    }
}

- (void)performTransmissionCycle {
    [self sendCoAPMessage];
    if (retransmissionCounter != 0) {
        [self sendDidRetransmitMessageToDelegateWithCoAPMessage:pendingCoAPMessageInTransmission];
    }
    
    if (retransmissionCounter != kMAX_RETRANSMIT) {
        double timeout = kACK_TIMEOUT * pow(2.0, retransmissionCounter) * (kACK_RANDOM_FACTOR - fmodf((float)random()/RAND_MAX, 0.5));
        sendTimer = [NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(performTransmissionCycle) userInfo:nil repeats:NO];
        retransmissionCounter++;
    }
}

- (void)sendCoAPMessage {
    [self.udpSocket sendData:[pendingCoAPMessageInTransmission data] toHost:pendingCoAPMessageInTransmission.host port:pendingCoAPMessageInTransmission.port withTimeout:-1 tag:udpSocketTag];
    udpSocketTag++;
}

- (void)closeExchange {
    if (pendingCoAPMessageInTransmission.usesHttpProxying) {
        [urlConnection cancel];
        urlConnection = nil;
        urlData = nil;
        urlRequest = nil;
    }
    else {
        self.udpSocket.delegate = nil;
        [self.udpSocket close];
        self.udpSocket = nil;
        [sendTimer invalidate];
        [maxWaitTimer invalidate];
    }
    
    recentNotificationDate = nil;
    pendingCoAPMessageInTransmission = nil;
    _isMessageInTransmission = NO;
}

- (void)resetState {
    [sendTimer invalidate];
    [maxWaitTimer invalidate];
    isObserveCancelled = NO;
    observeOptionValue = 0;
    recentNotificationDate = nil;
    _isMessageInTransmission = YES;
}

#pragma mark - HTTP Proxying

- (void)sendHttpMessageFromCoAPMessage:(ICoAPMessage *)coapMessage {
    [self resetState];
    NSString *urlString = [NSString stringWithFormat:@"http://%@:%i/%@:%i",coapMessage.httpProxyHost, coapMessage.httpProxyPort, coapMessage.host, coapMessage.port];
    urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:kMAX_TRANSMIT_WAIT];
    
    if (coapMessage.code != IC_GET) {
        [urlRequest setHTTPMethod:[self getHttpMethodForCoAPMessageCode:coapMessage.code]];
    }
    
    for (id key in coapMessage.optionDict) {
        NSMutableArray *values = [coapMessage.optionDict valueForKey:key];
        for (NSString *value in values) {
            [urlRequest addValue:value forHTTPHeaderField:[self getHttpHeaderFieldForCoAPOptionDelta:[key intValue]]];
        }
    }
    
    [urlRequest setHTTPBody:[coapMessage.payload dataUsingEncoding:NSUTF8StringEncoding]];
    urlConnection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self];
    if (!urlConnection) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Failed to send HTTP-Request." forKey:NSLocalizedDescriptionKey];
        [self sendFailWithErrorToDelegateWithError:[[NSError alloc] initWithDomain:kiCoAPErrorDomain code:IC_PROXYING_ERROR userInfo:userInfo]];
    }
}

#pragma mark - Mapping Methods for Proxying

- (NSString *)getHttpHeaderFieldForCoAPOptionDelta:(uint)delta {
    switch (delta) {
        case IC_IF_MATCH:       return @"IF_MATCH";
        case IC_URI_HOST:       return @"URI_HOST";
        case IC_ETAG:           return @"ETAG";
        case IC_IF_NONE_MATCH:  return @"IF_NONE_MATCH";
        case IC_URI_PORT:       return @"URI_PORT";
        case IC_LOCATION_PATH:  return @"LOCATION_PATH";
        case IC_URI_PATH:       return @"URI_PATH";
        case IC_CONTENT_FORMAT: return @"CONTENT_FORMAT";
        case IC_MAX_AGE:        return @"MAX_AGE";
        case IC_URI_QUERY:      return @"URI_QUERY";
        case IC_ACCEPT:         return @"ACCEPT";
        case IC_LOCATION_QUERY: return @"LOCATION_QUERY";
        case IC_PROXY_URI:      return @"PROXY_URI";
        case IC_PROXY_SCHEME:   return @"PROXY_SCHEME";
        case IC_BLOCK2:         return @"BLOCK2";
        case IC_BLOCK1:         return @"BLOCK1";
        case IC_OBSERVE:        return @"OBSERVE";
        case IC_SIZE1:          return @"SIZE1";
        case IC_SIZE2:          return @"SIZE2";
        default:                return nil;
    }
}

- (NSString *)getHttpMethodForCoAPMessageCode:(uint)code {
    switch (code) {
        case IC_POST:   return @"POST";
        case IC_PUT:    return @"PUT";
        case IC_DELETE: return @"DELETE";
        default:        return @"GET";
    }
}

- (ICoAPType)getCoapTypeForString:(NSString *)typeString {
    if ([typeString isEqualToString:@"CON"]) {
        return IC_CONFIRMABLE;
    }
    else if ([typeString isEqualToString:@"NON"]) {
        return IC_NON_CONFIRMABLE;
    }
    else if ([typeString isEqualToString:@"RES"]) {
        return IC_RESET;
    }
    else {
        return IC_ACKNOWLEDGMENT;
    }
}

#pragma mark - NSURL Connection Delegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self closeExchange];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Proxying Failure." forKey:NSLocalizedDescriptionKey];
    [self sendFailWithErrorToDelegateWithError:[[NSError alloc] initWithDomain:kiCoAPErrorDomain code:IC_PROXYING_ERROR userInfo:userInfo]];
}

#pragma mark - NSURL Connection Data Delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    urlData = [[NSMutableData alloc] init];
    proxyCoAPMessage = [[ICoAPMessage alloc] init];
    proxyCoAPMessage.isRequest = NO;
    
    NSHTTPURLResponse *httpresponse = (NSHTTPURLResponse *)response;
    
    for (NSNumber *optNumber in supportedOptions) {
        NSString *optString = [self getHttpHeaderFieldForCoAPOptionDelta:[optNumber intValue]];
        
        if ([httpresponse.allHeaderFields objectForKey:[NSString stringWithFormat:@"HTTP_%@", optString]]) {
            NSString *valueString = [httpresponse.allHeaderFields objectForKey:[NSString stringWithFormat:@"HTTP_%@", optString]];
            NSArray *valueArray = [valueString componentsSeparatedByString:@","];
            
            [proxyCoAPMessage.optionDict setValue:[NSMutableArray arrayWithArray:valueArray] forKey:[optNumber stringValue]];
        }
    }
    
    proxyCoAPMessage.type = [self getCoapTypeForString:[httpresponse.allHeaderFields objectForKey:kProxyCoAPTypeIndicator]];
    proxyCoAPMessage.code = (uint)httpresponse.statusCode;
    proxyCoAPMessage.usesHttpProxying = YES;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [urlData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    proxyCoAPMessage.payload = [proxyCoAPMessage requiresPayloadStringDecode] ? [NSString stringFromHexString:[NSString stringFromDataWithHex:urlData]] : [NSString stringFromDataWithHex:urlData];
    proxyCoAPMessage.timestamp = [[NSDate alloc] init];
    
    if ([proxyCoAPMessage.optionDict valueForKey:[NSString stringWithFormat:@"%i", IC_BLOCK2]] && ![proxyCoAPMessage.optionDict valueForKey:[NSString stringWithFormat:@"%i", IC_OBSERVE]]) {
        [self handleBlock2OptionForCoapMessage:proxyCoAPMessage];
    }
    else {
        _isMessageInTransmission = NO;
    }
    
    [self sendDidReceiveMessageToDelegateWithCoAPMessage:proxyCoAPMessage];
}

@end
