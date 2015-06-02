//
//  ExampleViewController.m
//  iCoAP_Example
//
//  Created by Wojtek Kordylewski on 26.07.13.


#import "ExampleViewController.h"
#import "ICoAPMessage+DisplayHelper.h"

static NSString * kICoAPConnectionHost = @"1.coap.me";
static uint kICoAPConnectionPort = 5683;

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

    if (!exchange.isMessageInTransmission) {
        self.activityIndicator.hidden = YES;
    }
    
    count++;
    NSString *codeString = [coapMessage codeDisplayString];
    NSString *typeString = [coapMessage typeDisplayString];
    NSString *dateString = [completeDateFormat stringFromDate:coapMessage.timestamp];

    NSMutableString *optString = [[NSMutableString alloc] init];
    for (id key in coapMessage.optionDict) {
        [optString appendString:@"Option: "];
        [optString appendString:[ICoAPMessage optionDisplayStringFromOptionDelta:[key intValue]]];
        
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
    // unless more messages are expected, like e.g. block messages, or observe messages.
    
    //          [iExchange closeExchange];


}
- (void)iCoAPExchange:(ICoAPExchange *)exchange didFailWithError:(NSError *)error {
    if (error.code == IC_UDP_SOCKET_ERROR || error.code == IC_RESPONSE_TIMEOUT) {
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
    ICoAPMessage *cO = [[ICoAPMessage alloc] initAsRequestConfirmable:YES requestMethod:IC_GET sendToken:YES payload:@""];
    [cO addOption:IC_URI_PATH withValue:self.textField.text];

    // add more Options here if required e.g. observe
    // [cO addOption:IC_OBSERVE withValue:@""];
    
    
    // finally initialize the ICoAPExchange Object. You can alternatively use the standard 'init' method
    // and set all properties manually.
    // coap.me is a test coap server you can use for testing. Note that it might be offline from time to time.
    if (!iExchange) {
        iExchange = [[ICoAPExchange alloc] initAndSendRequestWithCoAPMessage:cO toHost:kICoAPConnectionHost port:kICoAPConnectionPort delegate:self];
    }
    else {
        [iExchange sendRequestWithCoAPMessage:cO toHost:kICoAPConnectionHost port:kICoAPConnectionPort];
    }

    self.activityIndicator.hidden = NO;
}



@end
