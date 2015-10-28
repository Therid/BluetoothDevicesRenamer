#import <UIKit/UIKit.h>

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
static NSMutableArray* fields;

//reboot
static void reboot(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) 
{
    [(SpringBoard *)[UIApplication sharedApplication] reboot];
}

%ctor 
{
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,(CFNotificationCallback)reboot, CFSTR("rebootDevice"), NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
}

%hook PreferencesAppController

// get the BluetoothDevices list
-(BOOL)application:(id)arg1 didFinishLaunchingWithOptions:(id)arg2{
    %orig;
    fields= [[NSMutableArray alloc]init];
    devices= [[NSMutableDictionary alloc]initWithContentsOfFile: @"/var/mobile/Library/Preferences/com.apple.MobileBluetooth.devices.plist"];
    return %roig;
}

%end

//Add UIGestureRecognizer on all BTTableCell representing a paired device

%hook UITableViewLabel
-(void)layoutSubviews{
      %orig; 
      if([[devices allValues] count]!= 0 && self == self.tableCell.textLabel && [self.tableCell isKindOfClass: objc_getClass("BTTableCell")] == YES)
      {
           for (int i=0; i< [[devices allKeys] count]; i++)
           {
                  if ([self.text isEqualToString:[[[devices allValues] objectAtIndex:i]objectForKey:@"Name"]]==YES)
                  {
                            UITapGestureRecognizer* gesture = [[UITapGestureRecognizer alloc]initWithTarget: self action:@selector(beginEditName)];
                            [self setUserInteractionEnabled:YES];
                       //  gesture.numberOfTapsRequired = 2;
                         //UITapGestureRecognizer* gesture2 = [[UITapGestureRecognizer alloc]initWithTarget: self action:@selector(none)];
                        // [self addGestureRecognizer: gesture2];
                           [self addGestureRecognizer: gesture];
                  }
           }           
     }
}
%new
// Add a UITextField on the tapped cell and hide the cell's textLabel
-(void)beginEditName{
      if ([field superview]!= self.tableCell )
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
          [fields addObject: field];
          [[self superview] addSubview: field];
          [field becomeFirstResponder];
          self.alpha= 0.0;
     }
}
%new
-(void)none{
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
        %orig;   
        for(int i = 0; i<[fields count]; i++)
         {
              if (self== [fields objectAtIndex:i] && resign == NO)
              {
                  UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Reboot?"message:@"A reboot is needed to apply changes." preferredStyle:UIAlertControllerStyleAlert];
                  UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"Reboot" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                         NSMutableDictionary* newDevice= [devices objectForKey: deviceAdress];
                         if([((UITextField*)self).text isEqualToString:@""] == NO)
                        {
                            [newDevice setObject: ((UITextField*)self).text forKey:@"Name"];
                        }
                        else
                        {
                            [newDevice setObject:[newDevice objectForKey:@"DefaultName"] forKey:@"Name"];
                       }
                       [devices setObject: newDevice forKey: deviceAdress];
                       [devices writeToFile: @"/var/mobile/Library/Preferences/com.apple.MobileBluetooth.devices.plist" atomically: YES];  
                       CFNotificationCenterPostNotification (CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("rebootDevice"), NULL, NULL, false); }];
                UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action){
                       if ([((UITextField*)self) superview] != nil && ((UITableViewCell*)[[((UITextField*)self) superview]superview]).textLabel != nil)
                      {
                            ((UITableViewCell*)[[((UITextField*)self) superview]superview]).textLabel.alpha = 1.0;
                            [((UITextField*)self) removeFromSuperview];
                      }}];
                 [alert addAction:cancelAction];
                 [alert addAction:defaultAction];
                 [[[[UIApplication sharedApplication] keyWindow]rootViewController] presentViewController:alert animated:YES completion:nil];
              }
        }
        resign= NO;
        return %orig;
}
%end

%hook UITableView
//Force resign first responder if the user was in the UITextField during table'update (avoid crash)

-(void)_updateWithItems: (id) arg1 updateSupport: (id) arg2 {
   if (field.isFirstResponder == YES)
   {
       resign=YES;
       [field resignFirstResponder];
   }
    %orig;
}
%end