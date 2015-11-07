#import <UIKit/UIKit.h>
#import "rocketbootstrap.h"

@interface CPDistributedMessagingCenter
{
}
+(id)centerNamed:(id) center;
-(void)runServerOnCurrentThread;
-(void)sendMessageName:(NSString*) message userInfo:(NSDictionary*) info;
-(void)registerForMessageName: (NSString*) name target: (id) target selector: (SEL) selector ;
@end

@interface UITableViewLabel : UILabel <UITextFieldDelegate>
{
}
-(id)tableCell;
-(BOOL)textFieldShouldReturn: (UITextField*) textField;
@property (nonatomic,retain) UITableViewCell* tableCell;
@end

@interface SpringBoard : UIApplication
- (void)reboot;
@end

static UITextField* field;
static NSString* deviceAdress;
static NSMutableDictionary* devices;
static BOOL resign = NO;

%hook PreferencesAppController
// get the BluetoothDevices list
-(BOOL)application:(id)arg1 didFinishLaunchingWithOptions:(id)arg2{
    devices= [[NSMutableDictionary alloc]initWithContentsOfFile: @"/var/mobile/Library/Preferences/com.apple.MobileBluetooth.devices.plist"];
    return %orig;
}
%end

//Add UIGestureRecognizer on all BTTableCell representing a paired device
%hook UITableViewLabel
-(void)layoutSubviews{
      %orig; 
      if([[devices allValues] count]!= 0 && self == self.tableCell.textLabel && [self.tableCell isKindOfClass: [objc_getClass("BTTableCell") class]] == YES && [[NSBundle mainBundle].bundleIdentifier isEqualToString: @"com.apple.Preferences"] ==YES)
      {
           for (int i=0; i< [[devices allKeys] count]; i++)
           {
                  if ([self.text isEqualToString:[[[devices allValues] objectAtIndex:i]objectForKey:@"Name"]]==YES)
                  {
                            UITapGestureRecognizer* gesture = [[UITapGestureRecognizer alloc]initWithTarget: self action:@selector(beginEditName)];
                            [self setUserInteractionEnabled:YES];
                            [self addGestureRecognizer: gesture];
                  }
           }           
     }
}

%new
// Add a UITextField on the tapped cell and hide the cell's textLabel
-(void)beginEditName{
      if ([field superview]!= self.tableCell && [[NSBundle mainBundle].bundleIdentifier isEqualToString: @"com.apple.Preferences"] ==YES && field.isFirstResponder == NO)
      {
          for (int i=0; i<[[devices allKeys] count]; i++)
          {
                  if ([self.text isEqualToString:[[[devices allValues] objectAtIndex:i]objectForKey:@"Name"]]==YES)
                  {
                         deviceAdress = [[devices allKeys] objectAtIndex: i];
                  }
           }
           field= [[UITextField alloc]initWithFrame:self.frame];
           field.text = self.text;
           field.font = self.font;
           field.delegate = self;
          [[self superview] addSubview: field];
          [field becomeFirstResponder];
          self.alpha= 0.0;
     }
}
%new
//implement the return key
-(BOOL)textFieldShouldReturn: (UITextField*) textField{
    [textField resignFirstResponder];
    return YES;
}
%end


%hook UIResponder 
// Create an alert to ask to cancel changes or reboot to apply changes when the user quit the UITextField
-(BOOL)resignFirstResponder{
       if([[NSBundle mainBundle].bundleIdentifier isEqualToString: @"com.apple.Preferences"] ==YES && resign == NO  && field.isFirstResponder == YES)
       {
              %orig;
              UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Reboot?"message:@"A reboot is needed to apply changes." preferredStyle:UIAlertControllerStyleAlert];
              UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"Reboot" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                     CPDistributedMessagingCenter* c = [CPDistributedMessagingCenter centerNamed:@"com.alex.bluetoothrename"];
                     NSMutableDictionary* newDevice= [devices objectForKey: deviceAdress]; 
                     if([field.text isEqualToString:@""] == NO)
                    {
                        [newDevice setObject: field.text forKey:@"Name"];
                    }
                    else
                    {
                        [newDevice setObject:[newDevice objectForKey:@"DefaultName"] forKey:@"Name"];
                   }
                   [devices setObject: newDevice forKey: deviceAdress];
                   [devices writeToFile: @"/var/mobile/Library/Preferences/com.apple.MobileBluetooth.devices.plist" atomically: YES];  
                   rocketbootstrap_distributedmessagingcenter_apply(c);
                   [c sendMessageName:@"rebootAsked" userInfo:nil]; }];
            UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
                    ((UITableViewCell*)[[field superview]superview]).textLabel.alpha = 1.0;
                    [field removeFromSuperview];}];                          
             [alert addAction:cancelAction];
             [alert addAction:defaultAction];
             [[[[UIApplication sharedApplication] keyWindow]rootViewController] presentViewController:alert animated:YES completion:nil];
        }
        return %orig;
}
%end

%hook UITableView
//Force resign first responder if the user was in the UITextField during table'update (avoid crash)
-(void)_updateWithItems: (id) arg1 updateSupport: (id) arg2 {
       if(field.isFirstResponder == YES && [[NSBundle mainBundle].bundleIdentifier isEqualToString: @"com.apple.Preferences"] ==YES )
       {
             resign =YES;
             [field resignFirstResponder];
             resign = NO;
       }
       %orig;
}
%end

//prepare server to listen for reboot
%hook SpringBoard 
-(id)init
{
    CPDistributedMessagingCenter *c = [CPDistributedMessagingCenter centerNamed:@"com.alex.bluetoothrename"];
    rocketbootstrap_distributedmessagingcenter_apply(c);
    [c runServerOnCurrentThread];
    [c registerForMessageName:@"rebootAsked" target:self selector:@selector(rebootAsked)];
    return %orig;
}
%new
-(void)rebootAsked
{
     [self reboot];
}
%end