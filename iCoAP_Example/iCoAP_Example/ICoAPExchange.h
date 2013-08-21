//
//  ICoAPExchange.h
//  iCoAP
//
//  Created by Wojtek Kordylewski on 25.06.13.


/*
 *  This class represents a client-sided CoAP data exchange of the
 *  iCoAP iOS library.
 
 *  It is recommended to use new ICoAPExchange objects if
 *  a pending CoAP Message is in transmission and responses are
 *  still expected.
 
 *  Version 1.0
 
 *  Special Features:
 *          - Observe
 *          - Block transfer in responses (BLOCK 2)
 
 
 
 *  This version uses the public domain licensed CocoaAsyncSocket library
 *  for UDP-socket networking.
 *  See more on https://github.com/robbiehanson/CocoaAsyncSocket
 */



#import <Foundation/Foundation.h>
#import "GCDAsyncUdpSocket.h"
#import "ICoAPMessage.h"




#define k8bitIntForOption                   13
#define k16bitIntForOption                  14
#define kOptionDeltaPayloadIndicator        15

#define kMAX_RETRANSMIT                     4
#define kACK_TIMEOUT                        2.0
#define kACK_RANDOM_FACTOR                  1.5
#define kMAX_TRANSMIT_WAIT                  93.0

#define kiCoAPErrorDomain                   @"iCoAPErrorDomain"


typedef enum {
    NO_RESPONSE_EXPECTED,       //  MAX_WAIT time expired and no response is expected
    UDP_SOCKET_ERROR            //  UDP Socket setup/bind failed
}ICoAPExchangeErrorCode;





@interface ICoAPExchange : NSObject<GCDAsyncUdpSocketDelegate> {
    long udpSocketTag;
    ICoAPMessage *pendingCoAPMessageInTransmission;
    NSTimer *sendTimer;
    NSTimer *maxWaitTimer;
    int retransmissionCounter;
    
    int observeOptionValue;
    BOOL isObserveCancelled;
}







#pragma mark - Properties







@property (weak, nonatomic) id delegate;

/*
 *  'udpSocket':
 *  The GCDAsyncUdpSocket see https://github.com/robbiehanson/CocoaAsyncSocket
 *  for documentation of the library.
 */
@property (strong, nonatomic) GCDAsyncUdpSocket *udpSocket;

/*
 *  'udpPort':
 *  The udpPort for listening. (Optional)
 */
@property (readwrite, nonatomic) uint udpPort;

/*
 *  'isMessageInTransmission':
 *  Indicates if a ICoAPMessage is currently in transmission and
 *  if a successive message is expected.
 *  E.g. no response was is received yet, or an empty ACK message indicated a separate response,
 *  or a Block2 message with more-bit set indicated successive
 *  Block2 messages.
 */
@property (readonly, nonatomic) BOOL isMessageInTransmission;






#pragma mark - Accessible Methods








/*
 *  'initAndSendRequestWithCoAPMessage:toHost:port:delegate':
 *   Initializer with embedded message sending.
 */
- (id)initAndSendRequestWithCoAPMessage:(ICoAPMessage *)cO toHost:(NSString* )host port:(uint)port delegate:(id)delegate;

/*
 *  'sendRequestWithCoAPMessage:toHost:port':
 *  Starts the sending of the given ICoAPMessage to the destination 'host' and
 *  'port'.
 */
- (void)sendRequestWithCoAPMessage:(ICoAPMessage *)cO toHost:(NSString *)host port:(uint)port ;

/*
 *  'cancelObserve':
 *  Cancels an Observe subscription (if available).
 */
- (void)cancelObserve;

/*
 *  'closeTransmission':
 *  Closes the current transmission and Udp Socket.
 *  Should always be called, if a transmission is (expected to be) finished.
 */
- (void)closeTransmission;

/*
 *  'decodeCoAPMessageFromData':
 *  Decodes the given 'data' to an ICoAPMessage object.
 */
- (ICoAPMessage *)decodeCoAPMessageFromData:(NSData *)data;

/*
 *  'encodeDataFromCoAPMessage':
 *  Encodes the given ICoAPMessage to a ready-to-send NSData.
 */
- (NSData *)encodeDataFromCoAPMessage:(ICoAPMessage *)cO;

@end







#pragma mark - Delegate Protocol Definition







@protocol ICoAPExchangeDelegate <NSObject>
@optional

/*
 *  'iCoAPExchange:didReceiveCoAPMessage:':
 *  Informs the delegate that a valid ICoAPMessage was received.
 */
- (void)iCoAPExchange:(ICoAPExchange *)exchange didReceiveCoAPMessage:(ICoAPMessage *)coapMessage;

/*
 *  'iCoAPExchange:didFailWithError:':
 *  Informs the delegate that an error has occured. The error code matches the defined
 *  'ICoAPExchangeErrorCode'.
 */
- (void)iCoAPExchange:(ICoAPExchange *)exchange didFailWithError:(NSError *)error;

/*
 *  'iCoAPExchange:didRetransmitCoAPMessage:number:finalRetransmission:':
 *  Informs the delegate that the pending ICoAPMessage is about to be retransmitted.
 *  'final' indicates whether this was the last retransmission (MAX_RETRANSMIT reached),
 *  whereas 'number' represents the number of performed retransmissions.
 */
- (void)iCoAPExchange:(ICoAPExchange *)exchange didRetransmitCoAPMessage:(ICoAPMessage *)coapMessage number:(uint)number finalRetransmission:(BOOL)final;

@end