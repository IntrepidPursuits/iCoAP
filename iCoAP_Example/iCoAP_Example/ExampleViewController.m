//
//  ExampleViewController.m
//  iCoAP_Example
//
//  Created by Wojtek Kordylewski on 26.07.13.


#import "ExampleViewController.h"

@interface ExampleViewController ()

@end

@implementation ExampleViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    completeDateFormat = [[NSDateFormatter alloc] init];
    [completeDateFormat setDateFormat:@"EEE dd.MM.yyyy"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - iCoAP Exchange Delegate

- (void)iCoAPExchange:(ICoAPExchange *)exchange didReceiveCoAPMessage:(ICoAPMessage *)coapMessage {
    //If empty ACK Message received: Indicator for Seperate Message and don't hide activity indicator

    if (!exchange.isMessageInTransmission) {
        self.activityIndicator.hidden = YES;
    }
    
    count++;
    NSString *codeString = [self getCodeDisplayStringForCoAPObject:coapMessage];
    NSString *typeString = [self getTypeDisplayStringForCoAPObject:coapMessage];
    NSString *dateString = [completeDateFormat stringFromDate:coapMessage.timestamp];

    NSMutableString *optString = [[NSMutableString alloc] init];
    for (id key in coapMessage.optionDict) {
        [optString appendString:@"Option: "];
        [optString appendString:[self getOptionDisplayStringForCoAPOptionDelta:[key intValue]]];
        
        //Iterate over the array of option values
        NSMutableArray *valueArray = [coapMessage.optionDict valueForKey:key];
        for (uint i = 0; i < [valueArray count]; i++) {
            [optString appendString:[NSString stringWithFormat:@" \nValue (%i): ", i + 1]];
            [optString appendString:[valueArray objectAtIndex:i]];
            [optString appendString:@"\n"];
        }
        [optString appendString:@"\n-----\n"];
    }
    
    NSLog(@"---------------------------");
    NSLog(@"---------------------------");
    

    if (exchange == iExchange) {
        [self.textView setText:[NSString stringWithFormat:@"(%i) Message from: %@\n\nType: %@\nResponseCode: %@\n%@\nMessageID: %i\nToken: %i\nPayload: '%@'\n\n%@", count, dateString, typeString, codeString, optString , coapMessage.messageID, coapMessage.token, coapMessage.payload, self.textView.text]];
        
    }
    
    NSLog(@"\nMessage: %@\n\nType: %@\nResponseCode: %@\nOption: %@\nMessageID: %i\nToken: %i\nPayload: '%@'", dateString, typeString, codeString, optString, coapMessage.messageID, coapMessage.token, coapMessage.payload);
    NSLog(@"---------------------------");
    NSLog(@"---------------------------");
    
    // did you receive the expected message? then it is recommended to use the closeTransmission method
    // unless more messages are expected, like e.g. block message, or observe messages.
    
    //          [iExchange closeTransmission];


}
- (void)iCoAPExchange:(ICoAPExchange *)exchange didFailWithError:(NSError *)error {
    //Handle Errors
    if (error.code == UDP_SOCKET_ERROR || error.code == NO_RESPONSE_EXPECTED) {
        [self.textView setText:[NSString stringWithFormat:@"Failed: %@\n\n%@", [error localizedDescription], self.textView.text]];
        self.activityIndicator.hidden = YES;
    }
}


- (void)iCoAPExchange:(ICoAPExchange *)exchange didRetransmitCoAPMessage:(ICoAPMessage *)coapMessage number:(uint)number finalRetransmission:(BOOL)final {
    //Received retransmission notification
    [self.textView setText:[NSString stringWithFormat:@"Retransmission: %i\n\n%@", number, self.textView.text]];
}


#pragma mark - Text Field Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self onTapSend:self];
    return YES;
}

#pragma mark - Action

- (IBAction)onTapSend:(id)sender {
    [self.textField resignFirstResponder];
    // Create ICoAPMessage first. You can alternatively use the standard 'init' method
    // and set all properties manually
    ICoAPMessage *cO = [[ICoAPMessage alloc] initAsRequestConfirmable:YES requestMethod:GET sendToken:YES payload:@""];
    [cO addOption:URI_PATH withValue:self.textField.text];

    // add more Options here if required e.g. observe
    // [cO addOption:OBSERVE withValue:@""];
    
    
    // finally initialize the ICoAPExchange Object. You can alternatively use the standard 'init' method
    // and set all properties manually.
    // coap.me is a test coap server you can use for testing. Note that it might be offline from time to time.
    if (!iExchange) {
        iExchange = [[ICoAPExchange alloc] initAndSendRequestWithCoAPMessage:cO toHost:@"4.coap.me" port:5683 delegate:self];
    }
    else {
        [iExchange sendRequestWithCoAPMessage:cO toHost:@"4.coap.me" port:5683];
    }

    self.activityIndicator.hidden = NO;
}

#pragma mark - Display Helper

- (NSString *)getOptionDisplayStringForCoAPOptionDelta:(uint)delta {
    switch (delta) {
        case IF_MATCH:
            return @"If Match";
        case URI_HOST:
            return @"URI Host";
        case ETAG:
            return @"ETAG";
        case IF_NONE_MATCH:
            return @"If None Match";
        case URI_PORT:
            return @"URI Port";
        case LOCATION_PATH:
            return @"Location Path";
        case URI_PATH:
            return @"URI Path";
        case CONTENT_FORMAT:
            return @"Content Format";
        case MAX_AGE:
            return @"Max Age";
        case URI_QUERY:
            return @"URI Query";
        case ACCEPT:
            return @"Accept";
        case LOCATION_QUERY:
            return @"Location Query";
        case PROXY_URI:
            return  @"Proxy URI";
        case PROXY_SCHEME:
            return @"Proxy Scheme";
        case BLOCK2:
            return @"Block 2";
        case BLOCK1:
            return @"Block 1";
        case OBSERVE:
            return @"Observe";
        default:
            return [NSString stringWithFormat:@"Unknown: %i", delta];
    }
}

- (NSString *)getTypeDisplayStringForCoAPObject:(ICoAPMessage *)cO {
    switch (cO.type) {
        case CONFIRMABLE:
            return @"Confirmable (CON)";
        case NON_CONFIRMABLE:
            return @"Non Confirmable (NON)";
        case ACKNOWLEDGMENT:
            return @"Acknowledgment (ACK)";
        case RESET:
            return @"Reset (RES)";
        default:
            return [NSString stringWithFormat:@"Unknown: %i", cO.type];
    }
}

- (NSString *)getCodeDisplayStringForCoAPObject:(ICoAPMessage *)cO {
    switch (cO.code) {
        case EMPTY:
            return @"Empty";
        case CREATED:
            return @"Created";
        case DELETED:
            return @"Deleted";
        case VALID:
            return @"Valid";
        case CHANGED:
            return @"Changed";
        case CONTENT:
            return @"Content";
        case BAD_REQUEST:
            return @"Bad Request";
        case UNAUTHORIZED:
            return @"Unauthorized";
        case BAD_OPTION:
            return @"Bad Option";
        case FORBIDDEN:
            return @"Forbidden";
        case NOT_FOUND:
            return @"Not Found";
        case METHOD_NOT_ALLOWED:
            return @"Method Not Allowed";
        case NOT_ACCEPTABLE:
            return @"Not Acceptable";
        case PRECONDITION_FAILED:
            return @"Precondition Failed";
        case REQUEST_ENTITY_TOO_LARGE:
            return @"Request Entity Too Large";
        case UNSUPPORTED_CONTENT_FORMAT:
            return @"Unsupported Content Format";
        case INTERNAL_SERVER_ERROR:
            return @"Internal Server Error";
        case NOT_IMPLEMENTED:
            return @"Not Implemented";
        case BAD_GATEWAY:
            return @"Bad Gateway";
        case SERVICE_UNAVAILABLE:
            return @"Service Unavailable";
        case GATEWAY_TIMEOUT:
            return @"Gateway Timeout";
        case PROXYING_NOT_SUPPORTED:
            return @"Proxying Not Supported";
        default:
            return [NSString stringWithFormat:@"Unknown: %i", cO.code];
    }
}

@end
