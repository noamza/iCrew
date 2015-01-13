//
//  NZAMainViewController.m
//  iCrew
//
//  Created by Almog, Noam (ARC-AF)[UNIV OF CALIFORNIA   SANTA CRUZ] on 3/7/14.
//  Copyright (c) 2014 Almog, Noam (ARC-AF)[UNIV OF CALIFORNIA   SANTA CRUZ]. All rights reserved.
//

#import "NZAMainViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
//#import "Transmitter.h"
#import <FYX/FYX.h>
#import <FYX/FYXLogging.h>
#import <FYX/FYXVisitManager.h>
#import <FYX/FYXSightingManager.h>
#import <FYX/FYXTransmitter.h>
#import <FYX/FYXVisit.h>
#import <CoreBluetooth/CoreBluetooth.h>


@interface NZAMainViewController () <CLLocationManagerDelegate, UITableViewDelegate, UITableViewDataSource, FYXServiceDelegate, FYXVisitDelegate, FYXiBeaconVisitDelegate,  CBPeripheralManagerDelegate >

    @property (weak, nonatomic) IBOutlet UIButton *transmitButton; //comment
    @property (weak, nonatomic) IBOutlet UILabel *status;
    @property (weak, nonatomic) IBOutlet UITextField *idNameTextField;
    @property (strong, nonatomic) IBOutlet UISearchDisplayController *sdController;
    @property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
    @property (weak, nonatomic) IBOutlet MKMapView *map;
    @property (weak, nonatomic) IBOutlet UILabel *btAirport; //, *btSecurity, *btGate;
    @property (weak, nonatomic) IBOutlet UIProgressView *progressBar;
    //Gimbal
    @property NSMutableArray *transmitters;
    @property FYXVisitManager *visitManager;
    //as iBeacon
    @property CBPeripheralManager * peripheralManager;

    @property (weak, nonatomic) IBOutlet UISlider *beaconSlider;
    @property (weak, nonatomic) IBOutlet UILabel *rssi;

@end
@implementation NZAMainViewController

//new server
//@"http://ec2-54-186-31-103.us-west-2.compute.amazonaws.com/flightcrewang/app/ajax/addCrew.php";addCheckIn.php";
NSString *serverURL  = @"http://ec2-54-186-31-103.us-west-2.compute.amazonaws.com/flightcrewang/app/ajax/";
NSString *addCrewURL = @"";
NSString *checkInURL = @"";
CLLocationManager *manager;
CLGeocoder *geocoder;
CLPlacemark *placemark;
BOOL stopped = true;
bool startup = true;
bool getETA = false;
double currentLat = 0, currentLon = 0,  destinationLat = 0, destinationLon= 0;
//double destinationLat = 37.41500000; //moffett // double destinationLat = 36.9984322; //santa
//double destinationLon= -122.0483000; //moffett // double destinationLon= -122.03427220000003; //cruz
NSString * idname = @"";
NSTimer *timer;
NSMutableArray *searchResults;
NSString *destination = @"";
int gpsInterval = 5;
CLRegion * region;
double timeOfLastUpload = -1;
float rssiThreshold = 30.0f;

//Transmitting as iBeacon
CBPeripheralManager * myPeripheralManager;

- (void)test{NSLog(@"yes indeed this test worked");}

// First thing called when app view first loads
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [FYX setAppId:@"8a177ebc653abf803b4eef5841d2c6f037bb1c6a97f1c6f7b8534879b81bebc3"
        appSecret:@"5b8523e0e9d02aaeec7f4376fd8601609c8ea6426a8ed333efb3a6077699374c"
      callbackUrl:@"ios://authcode"];
    [FYX startService:self];
    
    addCrewURL = [NSString stringWithFormat:@"%@addCrew.php",serverURL]; //commit test
    checkInURL = [NSString stringWithFormat:@"%@addCheckIn.php",serverURL];
    //makes progress bar wider
    CGAffineTransform transform = CGAffineTransformMakeScale(1.0f, 7.0f);
    self.progressBar.transform = transform;
    self.progressBar.progress = 0;
    
    //restore data from what has been saved previously
    if([[NSUserDefaults standardUserDefaults] stringForKey:@"idname"] != nil){
        idname = [[NSUserDefaults standardUserDefaults] stringForKey:@"idname"];
        self.idNameTextField.text = idname;
    }
    if([[NSUserDefaults standardUserDefaults] stringForKey:@"destination"] != nil) {
        destination = [[NSUserDefaults standardUserDefaults] stringForKey:@"destination"];
        self.searchBar.text = destination;
        destinationLat = [[NSUserDefaults standardUserDefaults] doubleForKey:@"destinationLat"];
        destinationLon = [[NSUserDefaults standardUserDefaults] doubleForKey:@"destinationLon"];
    }
    if([[NSUserDefaults standardUserDefaults] stringForKey:@"rssiThreshold"] != nil) {
        self.beaconSlider.value = [[NSUserDefaults standardUserDefaults] floatForKey:@"rssiThreshold"];
        rssiThreshold = [[NSUserDefaults standardUserDefaults] floatForKey:@"rssiThreshold"];
        self.rssi.text = [NSString stringWithFormat:@"%.1f", rssiThreshold];
    }
    
    //Initialize location manager
    //@"37.732015,-122.432492";//@"25 Rousseau Street, San Francisco, CA";//@"101 Bayshore Boulevard, San Francisco, CA 94124";
	manager = [[CLLocationManager alloc] init];
    manager.delegate = self;
    manager.desiredAccuracy = kCLLocationAccuracyBest; //try best for navigation?
    geocoder = [[CLGeocoder alloc] init];
    [manager startUpdatingLocation];
    
    /*
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:tap];
     */
    int tempLen = (int)destination.length > 15? 15 : destination.length; //avoid long log names
    NSLog(@"started up from off, stored data: %@ * %@... * %f * %f", idname,
          [destination substringToIndex:tempLen], destinationLat, destinationLon);
    
    [self initBeacon];
    
}

- (IBAction)sliderValueChanged:(id)sender {
    if (sender == self.beaconSlider) {
        rssiThreshold = self.beaconSlider.value;
        //self.btAirport.text = [NSString stringWithFormat: @"%@ (rssi limit %f)", self.btAirport.text, self.beaconSlider.value];
        self.rssi.text = [NSString stringWithFormat: @"rssi %.1f",rssiThreshold];
        if(rssiThreshold == 30.0f){
            self.progressBar.progress = 0.f;
            self.btAirport.text = @"";
        }
        [[NSUserDefaults standardUserDefaults] setFloat:rssiThreshold forKey:@"rssiThreshold"];
    }
}


//bluetooth functions

CLBeaconRegion *beaconRegion;
NSMutableDictionary *beaconPeripheralData;
/*
- (void)beBT
{
    peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil options:nil];
}
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    //indicates whether the peripheral manager is available, is called when the peripheral manager’s state is updated.
}
 */

- (void)initBeacon {
    NSLog(@"Starting beacon");
    //                                                 @"A0000000-0000-0000-0000-00000000000A"
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString: @"C0ffEEBB-AF00-0000-0000-CAFE00000001"];//@"23542266-18D1-4FE4-B4A1-23F8195B9D39"];
    beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid
                                                                major:1
                                                                minor:1
                                                           identifier:@"the iCrew beacon"];
    [self transmitBeacon:self];
}

- (IBAction)transmitBeacon:(id)sender {
    beaconPeripheralData = [beaconRegion peripheralDataWithMeasuredPower:nil];
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self
                                                                     queue:nil
                                                                   options:nil];
}

-(void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    NSLog(@"peripheralManager (*))(*)(*()*###())(*()*()*()*");
    
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        NSLog(@"peripheralManager Powered On");
        [self.peripheralManager startAdvertising:beaconPeripheralData];
    } else if (peripheral.state == CBPeripheralManagerStatePoweredOff) {
        NSLog(@"peripheralManager Powered Off");
        [self.peripheralManager stopAdvertising];
    }
}




//Called when gimbal bluetooth is started
- (void)serviceStarted
{
    NSLog(@"Gimbal proximity service started");
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"fyx_service_started_key"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.transmitters = [NSMutableArray new];
    self.visitManager = [[FYXVisitManager alloc] init];
    self.visitManager.delegate = self;
    self.visitManager.iBeaconDelegate = self;
    //[self.visitManager start];
    [self.visitManager startWithOptions:@{FYXVisitOptionDepartureIntervalInSecondsKey:@5,FYXSightingOptionSignalStrengthWindowKey:@(FYXSightingOptionSignalStrengthWindowNone)}];
}

//called whenever device detects bluetooth beacon
- (void)receivedSighting:(FYXVisit *)visit updateTime:(NSDate *)updateTime RSSI:(NSNumber *)RSSI
{
    //*
    NSString *theInfo = [NSString stringWithFormat: @"name %@ RSSI %@ battery %@ temperature %@",
                         [visit.transmitter.name substringToIndex:2], //for B1 which is longer.
                         RSSI,
                         visit.transmitter.battery,
                         visit.transmitter.temperature]; theInfo = theInfo;
     //NSLog(@"%@", theInfo);
    if([RSSI floatValue] > - rssiThreshold){ //why multiple times
        //NSLog(@"pbar %f", self.progressBar.progress);
        if ([visit.transmitter.name rangeOfString:@"B1"].location != NSNotFound){
            if(self.progressBar.progress < 1/3.0f){
                NSLog(@"%@ RSSI %@ %.1f",[visit.transmitter.name substringToIndex:2], RSSI, rssiThreshold);
                self.btAirport.text = @"Ticket Checked";
                self.progressBar.progress = 1/3.0f;
                [self checkInPassegerOnServer:@"1"];
            }
        }
        
        if ([visit.transmitter.name rangeOfString:@"B1"].location != NSNotFound){ //B2
            if(self.progressBar.progress < 2/3.0f){
                NSLog(@"%@ RSSI %@ %.1f",[visit.transmitter.name substringToIndex:2], RSSI, rssiThreshold);
                self.progressBar.progress = 2/3.0f;
                self.btAirport.text = @"Passed Security";
                [self checkInPassegerOnServer:@"2"];
            }
        }
        
        if ([visit.transmitter.name rangeOfString:@"B2"].location != NSNotFound){ //B3
            if(self.progressBar.progress < 1/1.0f){
                NSLog(@"%@ RSSI %@ %.1f",[visit.transmitter.name substringToIndex:2], RSSI, rssiThreshold);
                self.btAirport.text = @"At Gate";
                self.progressBar.progress = 3/3.0f;
                [self checkInPassegerOnServer:@"3"];
            }
        }
    }
    // */
}

//stores passenger checkin process on server database
- (void) checkInPassegerOnServer: (NSString *) fence
{
    NSNumber *date = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
    double time = [date doubleValue]*1000.0;
    
    NSMutableURLRequest *theRequest=[NSMutableURLRequest
                                     requestWithURL:[NSURL URLWithString:checkInURL]
                                     cachePolicy:NSURLRequestUseProtocolCachePolicy
                                     timeoutInterval:60.0];
    NSString *name=[NSString stringWithFormat:@"'%@'",idname];
    NSString* data = @"empty";
    data = [NSString stringWithFormat: @"id=%@&time=%.0f&locationid=%@",name,time,fence];
    //NSLog(@"sending %@ to %@",data, checkInURL);
    NSData* strData = [data dataUsingEncoding:NSUTF8StringEncoding];
    [theRequest setHTTPMethod:@"POST"];
    [theRequest setHTTPBody:strData];
    [theRequest addValue:@"utf-8" forHTTPHeaderField:@"charset"];
    NSURLConnection *con = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
    if (con) {
        //_receivedData=[theRequest ];
        NSLog(@"%@ successfully Checked In server", data);
    } else {
        NSLog(@"%@",@"!!!!!!!!!!!!!!!!!!!!!!!!!!connection error to CHECK IN server");
    }
}

//      iBeacon Code
/*
- (void)didArriveIBeacon:(FYXiBeaconVisit *)visit;
{
    // this will be invoked when a managed Gimbal beacon is sighted for the first time
    NSLog(@"Ibeacon didArriveIBeacon ! Proximity UUID:%@ Major:%@ Minor:%@", visit.iBeacon.uuid, visit.iBeacon.major, visit.iBeacon.minor);
}
- (void)receivedIBeaconSighting:(FYXiBeaconVisit *)visit updateTime:(NSDate *)updateTime RSSI:(NSNumber *)RSSI;
{
    // this will be invoked when a managed Gimbal beacon is sighted during an on-going visit
    NSLog(@"Ibeacon receivedIBeaconSighting! Proximity UUID:%@ Major:%@ Minor:%@", visit.iBeacon.uuid, visit.iBeacon.major, visit.iBeacon.minor);
    
    NSString * temp = self.btAirport.text;
    //self.btAirport.text = @"ibeacon!";
    self.btAirport.text = [self.btAirport.text isEqualToString:@"ibeacon!"] || [self.btAirport.text isEqualToString:@"departed!"]? @"": @"ibeacon!";
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(clearLabel:) userInfo: temp repeats:NO];
}

-(void) clearLabel:(NSTimer *) tt
{
    NSLog(@"cl: %@ ui: %@", self.btAirport.text, tt.userInfo);
    self.btAirport.text = tt.userInfo;
    //self.btAirport.text = [tt.userInfo isEqualToString:@"ibeacon!"] || [tt.userInfo isEqualToString:@"departed!"]? @"": tt.userInfo;
    NSLog(@"cl: %@ ui: %@", self.btAirport.text, tt.userInfo);
    tt = nil;
    
}

- (void)didDepartIBeacon:(FYXiBeaconVisit *)visit;
{
    // this will be invoked when a managed Gimbal beacon has not been sighted for some time
    NSLog(@"Ibeacon didDepartIBeacon! Proximity UUID:%@ Major:%@ Minor:%@", visit.iBeacon.uuid, visit.iBeacon.major, visit.iBeacon.minor);
    NSLog(@"I was around the beacon for %f seconds", visit.dwellTime);
    
    NSString * temp = self.btAirport.text;
    self.btAirport.text = @"departed!";
    //self.btAirport.text = [self.btAirport.text isEqualToString:@"ibeacon!"] || [self.btAirport.text isEqualToString:@"departed!"]? @"": @"departed!";
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(clearLabel:) userInfo: temp repeats:NO];
    
}
 //*/

//<-- end beacon methods -->


//called everytime search text is entered
-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterContentForSearchText:searchString
                               scope:[[self.searchDisplayController.searchBar scopeButtonTitles]
                                      objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    return YES;
}

//called everytime search text is entered cont..
- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    if(searchText.length > 2){ //don't show results when only a few characters have been entered
        [self getDestination:searchText];
    } else {
        [searchResults removeAllObjects];
    }
}

//search view table
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{   //tells table how large to be based on destination search results array
    return [searchResults count];
}

//populates search table
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"CustomTableCell";
    UITableViewCell *cell = (UITableViewCell *)[self.searchDisplayController.searchResultsTableView dequeueReusableCellWithIdentifier:CellIdentifier];
    // Configure the cell...
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    // Display search results from Apple in the table cell
    NSDictionary *location = nil;
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        location = [searchResults objectAtIndex:indexPath.row];
    }
    cell.textLabel.text = location[@"address"];
    return cell;
}

//getting destionation from search results table when cell is selected
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    NSDictionary *location = [searchResults objectAtIndex:indexPath.row];
    destination = location[@"address"];
    destinationLat = [(NSNumber*) location[@"lat"] doubleValue];
    destinationLon = [(NSNumber*) location[@"lon"] doubleValue];
    //saving to persistent mem
    [[NSUserDefaults standardUserDefaults] setObject:destination    forKey:@"destination"];
    [[NSUserDefaults standardUserDefaults] setDouble:destinationLat forKey:@"destinationLat"];
    [[NSUserDefaults standardUserDefaults] setDouble:destinationLon forKey:@"destinationLon"];
    [[NSUserDefaults standardUserDefaults] synchronize];
   
    NSLog(@"destination set and stored as: %@ %f %f", destination, destinationLat,destinationLon);
    [self.searchDisplayController setActive:NO];
    [self.searchBar resignFirstResponder];
    [self.searchBar setText:destination];
    self.status.text = @"";
}

-(void) storeName:(NSString *) name
{
    idname = name;
    //saving to persistent memory and setting progress bar to 0
    [[NSUserDefaults standardUserDefaults] setObject:idname forKey:@"idname"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.progressBar.progress = 0;
    self.status.text = @"";
    NSLog(@"dismissKeyboard  name entered and stored: %@", idname);
    
}

//saving name from keyboard
-(void)dismissKeyboard {
    if(![self.idNameTextField.text isEqualToString: @""]){
        [self.idNameTextField resignFirstResponder];
        NSLog(@"dismissKeyboard for idname");
        [self storeName: self.idNameTextField.text];
    }
}

//saving idname from textfield
- (BOOL)textFieldShouldReturn:(UITextField *)textField { //is there another way to save?
    if (textField == self.idNameTextField) {
        [textField resignFirstResponder];
        NSLog(@"textFieldShouldReturn for idname");
        [self storeName: self.idNameTextField.text];
        return NO;
    }
    return YES;
}

//saving idname from textfield
- (IBAction)idEntered:(id)sender {
    NSLog(@"idEntered for idname");
    [self storeName: self.idNameTextField.text];
}

-(void):(UIScrollView *)scrollView {[self.view endEditing:YES];}

//start transmitting button
- (IBAction)touchUpEvent:(id)sender {
    NSLog(@"pressing button here here!");
    stopped= !stopped;
    if(!stopped){
        if ([idname isEqualToString:@""]){
            self.status.text = @"Please enter ID.";
            stopped= !stopped;
            return;
        }
        if ([destination isEqualToString:@""] || destinationLat == 0 || destinationLon == 0){
            self.status.text = @"Please re-enter destination.";
            stopped = !stopped;
            return;
        }
        //starting transmission with correct variables
        startup = NO;
        [manager startUpdatingLocation];
        NSLog(@"starting update");
        self.status.text = @"transmitting";
        [self.transmitButton setTitle:@"Stop" forState:(UIControlStateNormal)];
        [searchResults removeAllObjects]; // [self getDestination:@""]; why is this being called ??
    } else {
        //stop button hit
        [manager stopUpdatingLocation];
        NSLog(@"stopping update");
        self.status.text = @"stopped";
        [self.transmitButton setTitle:@"Transmit Location" forState:(UIControlStateNormal)];
    }
}

//initWithNibName: not sure I need this?
/*
//initialized from nib
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    NSLog(@"initWithNibName");
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        //stopped = true;
    }
    return self;
}
//*/

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//uploads to Amazon
- (void) sendToServer: (NSString *) route eta: (NSString *) eta
{
    NSNumber *time = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
    time = [NSNumber numberWithDouble:[time doubleValue]*1000.0];
    NSString *lat=[NSString stringWithFormat:@"%.10f",currentLat];
    NSString *lon=[NSString stringWithFormat:@"%.10f",currentLon];
    NSString *dlat=[NSString stringWithFormat:@"%.10f",destinationLat];
    NSString *dlon=[NSString stringWithFormat:@"%.10f",destinationLon];
    NSString *name=[NSString stringWithFormat:@"'%@'",idname];
    if(getETA)route = [NSString stringWithFormat:@"'%@'",route];
    //NSLog(@"id %@ time %@ lat %@ lon %@ eta %@", name, time, lat, lon, eta); NSLog(@"route %@",route);
    //NSMutableData* _receivedData;
    NSMutableURLRequest *theRequest=[NSMutableURLRequest
                                     requestWithURL:[NSURL URLWithString:addCrewURL]
                                     cachePolicy:NSURLRequestUseProtocolCachePolicy
                                     timeoutInterval:60.0];
    NSString* data = @"empty";
    if(getETA){
        data = [NSString stringWithFormat: @"id=%@&time=%@&latitude=%@&longitude=%@&route=%@&eta=%@",name,time,lat,lon,route,eta];
    } else {
        data = [NSString stringWithFormat: @"id=%@&time=%@&lat=%@&lon=%@&destlat=%@&destlon=%@",name,time,lat,lon,dlat,dlon];
    }
    NSLog(@"sending... %@ \nto %@",data, addCrewURL);
    NSData* strData = [data dataUsingEncoding:NSUTF8StringEncoding];
    [theRequest setHTTPMethod:@"POST"];
    [theRequest setHTTPBody:strData];
    [theRequest addValue:@"utf-8" forHTTPHeaderField:@"charset"];
    NSURLConnection *con = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
    if (con) {
        //_receivedData=[theRequest ];
        //NSLog(@"%@ successfully uploaded to server", idname);
    } else {
        NSLog(@"%@",@"!!connection error to server!!");
    }
}

//gets addresses from search string from Apple
- (void)getDestination: (NSString *) text
{ //make sure results are local
    __block NSMutableArray *temp = [[NSMutableArray alloc] init];
    //NSLog(@"region %@", region);
    [geocoder geocodeAddressString:text inRegion:region completionHandler:^(NSArray* placemarks, NSError* error){
        //NSLog(@"gettingDestination: # of placemarks %d", [placemarks count]);
        for (CLPlacemark* aPlacemark in placemarks)
        {
            //for (NSString *key in aPlacemark.addressDictionary){}
            NSArray *adArr = [aPlacemark.addressDictionary valueForKey:@"FormattedAddressLines"];
            if([[aPlacemark.addressDictionary valueForKey:@"FormattedAddressLines"] count]==3){
                NSString *address = [NSString stringWithFormat:@"%@, %@",adArr[0], adArr[1] /*[2]*/ ];
                NSNumber *lat = [NSNumber numberWithDouble:aPlacemark.location.coordinate.latitude];
                NSNumber *lon = [NSNumber numberWithDouble:aPlacemark.location.coordinate.longitude];
                NSDictionary * dest=@{@"address":address,@"lat":lat,@"lon":lon};
                [temp addObject: dest];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            searchResults = temp;
            [self.sdController.searchResultsTableView reloadData];
        });
        
    }];
}

//gets route from google
- (void)getRoute
{
    NSNumber *time = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
    if(time.doubleValue - timeOfLastUpload >= gpsInterval-2){ //make sure we don't send multiple requests
        //request to google server
        NSString *url = [NSString stringWithFormat: @"http://maps.googleapis.com/maps/api/directions/json?origin=%f,%f&destination=%f,%f&sensor=true&mode=%@",currentLat,currentLon,destinationLat,destinationLon,@"driving"];
            NSMutableURLRequest *theRequest=[NSMutableURLRequest
                                         requestWithURL:[NSURL URLWithString:url]
                                         cachePolicy:NSURLRequestUseProtocolCachePolicy
                                         timeoutInterval:60.0];
        [theRequest setHTTPMethod:@"GET"];
        [theRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSError *error;NSURLResponse *response; NSData * data;
        //route data returned from google
        data = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&response error:&error];
        //NSLog(@"returned data %@", data);
        if(data != nil)
        {
            //catch exceptions..!!!!!!
            NSDictionary *parsedObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            NSArray *routesArr = [parsedObject valueForKey:@"routes"];
            NSDictionary *route = routesArr[0];
            NSDictionary *overview_polyline = [route valueForKey:@"overview_polyline"];
            NSString *polyEncoded = [overview_polyline valueForKey:@"points"];
            NSString *polyDecoded = [self decodePoly:polyEncoded];
            //NSLog(@"decoded before: %@", polyDecoded);
            if(polyDecoded.length > 0){
                polyDecoded = [polyDecoded substringToIndex:polyDecoded.length-1]; //out of bounds; string length 0'
            } else {
                NSLog(@"no poly to draw");
                polyDecoded = @"";
            }
            //NSLog(@"encoded: %@", polyEncoded); NSLog(@"decoded after: %@", polyDecoded);
            NSArray *legsArr = [route valueForKey:@"legs"];
            NSDictionary *leg = legsArr[0];
            NSDictionary *duration = [leg valueForKey:@"duration"];
            NSString *valueInSec = [duration valueForKey:@"value"];
            //debugging
            /*
            NSLog(@"the value in seconds: %@", valueInSec);
            NSArray *steps = [leg valueForKey:@"steps"];
            NSLog(@"%@", @"steps:::::::::");
            for (NSString *key in leg) {
                NSLog(@"key %@", key);
                NSLog(@"key %@ value %@",key,[tempDic valueForKey:key]);
            }
            for (NSString *key in route) {
                NSLog(@"key %@", key);
                NSLog(@"key %@ value %@",key,[tempDic valueForKey:key]);
            }
            for (NSDictionary *tempDic in steps) {
                for (NSString *key in tempDic) {
                    NSLog(@"steps key %@", key);
                    NSLog(@"key %@ value %@",key,[tempDic valueForKey:key]);
                }
                
            }
             */
            timeOfLastUpload = time.doubleValue;
            NSLog(@"successfully received data from google");
            [self sendToServer:polyDecoded eta:valueInSec];
        } else {
            NSLog(@"google returned nothing, try again");
            [self getRoute];
        }
    }
}

//decodes route object from google (transleted from corresponding android app
- (NSMutableString *)decodePoly: (NSString *) encoded
{
    NSMutableString *poly = [[NSMutableString alloc] init];
    int index = 0,len = [encoded length], lat = 0, lng = 0, counter = 0;
    while (index < len) {
        counter++; int b, shift = 0, result = 0;
        do { b = [encoded characterAtIndex:index++] - 63; result |= (b & 0x1f) << shift; shift += 5;}
        while (b >= 0x20);
        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));lat += dlat;shift = 0; result = 0;
        do { b = [encoded characterAtIndex:index++] - 63; result |= (b & 0x1f) << shift; shift += 5;}
        while (b >= 0x20);
        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));lng += dlng;
        //LatLng position = new LatLng((double) lat / 1E5, (double) lng / 1E5);
        double latf = lat / 1E5; double lonf = lng / 1E5;
        if ((counter % 5) == 0){
            NSString * temp = [NSString stringWithFormat:@"%f,%f|",latf, lonf]; [poly appendString:temp];
        } else{
            continue;
        }
    }
    return poly;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{ NSLog(@"Failed to get location! Error: %@", error);}


- (void)locationManagerDidPauseLocationUpdates:(CLLocationManager *)manager
{
    NSLog(@"paused");
}

//starts location update loop everytime gps hardware gets a new location
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    CLLocation *currentLocation = newLocation;
    if (currentLocation != nil) {
        currentLat = currentLocation.coordinate.latitude;
        currentLon = currentLocation.coordinate.longitude;
        NSLog(@"didUpdateToLocation cur lat: %.10f lon: %.10f",currentLat, currentLon);
        //set current region
        region = [[CLRegion alloc] initCircularRegionWithCenter:[currentLocation coordinate] radius:10000 identifier:@"here"]; // radius in meters
        //stop updating and start timer to get location again in set sumber of seconds (gpsInterval)
        if([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive){
            [manager stopUpdatingLocation];
            timer = [NSTimer scheduledTimerWithTimeInterval:gpsInterval target:self selector:@selector(turnOnLocationManager)  userInfo:nil repeats:NO];
        }
        // set Span
        MKCoordinateSpan span;
        //You can set span for how much Zoom to be display like below
        span.latitudeDelta=.1;
        span.longitudeDelta=.1;
        //set Region to be display on MKMapView
        MKCoordinateRegion cordinateRegion;
        cordinateRegion.center = currentLocation.coordinate;
        //latAndLongLocation coordinates should be your current location to be display
        cordinateRegion.span=span;
        //set That Region mapView 
        [self.map setRegion:cordinateRegion animated:YES];
        [self.map showsUserLocation];
        //[self.map showsUserLocation];
        //get route send to server
        if(getETA) {
            if(!startup)[self getRoute];
        } else {
            if(!startup)[self sendToServer:@"-1" eta:@"-1"];
        }

    }
}

//called after app comes back from background
- (void)setLocationBackToNormal
{
    NSLog(@"came back FROM background");
    if(!stopped){
        manager = [[CLLocationManager alloc] init];
        manager.delegate = self;
        manager.desiredAccuracy = kCLLocationAccuracyBest;
        geocoder = [[CLGeocoder alloc] init];
        [manager startUpdatingLocation];
    }
}

//get's location in the background
- (void)getBGLocation
{
    //[FYX startService:self];
    [[NSUserDefaults standardUserDefaults] synchronize]; //help keep data persistent(?)
    if(!stopped){
        NSLog(@"starting background location");
        manager = [[CLLocationManager alloc] init];
        manager.delegate = self;
        manager.desiredAccuracy = kCLLocationAccuracyBest;
        geocoder = [[CLGeocoder alloc] init];
        [manager startMonitoringSignificantLocationChanges];
        [manager startUpdatingLocation];
    }
}

//called by timer set in didUpdateToLocation
- (void) turnOnLocationManager {
    if(!stopped)[manager startUpdatingLocation];
}

@end
