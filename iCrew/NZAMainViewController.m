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


@interface NZAMainViewController () <CLLocationManagerDelegate, UITableViewDelegate, UITableViewDataSource, FYXServiceDelegate, FYXVisitDelegate>

@property (weak, nonatomic) IBOutlet UIButton *transmitButton; //comment
@property (weak, nonatomic) IBOutlet UILabel *status;
@property (weak, nonatomic) IBOutlet UITextField *idNameTextField;
@property (strong, nonatomic) IBOutlet UISearchDisplayController *sdController;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (weak, nonatomic) IBOutlet MKMapView *map;
@property (weak, nonatomic) IBOutlet UILabel *btAirport; //, *btSecurity, *btGate;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;

@property NSMutableArray *transmitters;
@property FYXVisitManager *visitManager;

@end

@implementation NZAMainViewController

//NSString *serverUrl = @"http://ec2-54-200-25-136.us-west-2.compute.amazonaws.com/n.php";
//NSString *serverUrl = @"http://ec2-54-200-25-136.us-west-2.compute.amazonaws.com/test.php";
//NSString *serverUrl = @"http://ec2-54-200-25-136.us-west-2.compute.amazonaws.com/flightcrewang/app/ajax/addCrew.php";
//new server
NSString *serverURL = @"http://ec2-54-186-31-103.us-west-2.compute.amazonaws.com/flightcrewang/app/ajax/";

NSString *addCrewURL = @"http://ec2-54-186-31-103.us-west-2.compute.amazonaws.com/flightcrewang/app/ajax/addCrew.php";

NSString *checkInURL = @"http://ec2-54-186-31-103.us-west-2.compute.amazonaws.com/flightcrewang/app/ajax/addCheckIn.php";

CLLocationManager *manager;
CLGeocoder *geocoder;
CLPlacemark *placemark;
BOOL stopped = true;
bool startup = true;
bool getETA = false;
double currentLat = 0; 
double currentLon = 0;
//double destinationLat = 37.41500000; //moffett
//double destinationLon= -122.0483000; //moffett
//double destinationLat = 36.9984322; //santa
//double destinationLon= -122.03427220000003; //cruz
double destinationLat = 0; //santa
double destinationLon= 0; //cruz
NSString * idname = @"";
NSTimer *timer;
NSMutableArray *searchResults;
NSString *destination = @"";
int gpsInterval = 5;
CLRegion * region;
double timeOfLastUpload = -1;

//TODO check whether named entered..
//request is asynchronous, should display results when done

- (void)test{NSLog(@"yes indeed this test worked");}

- (void)viewDidLoad
{
    [FYX setAppId:@"8a177ebc653abf803b4eef5841d2c6f037bb1c6a97f1c6f7b8534879b81bebc3"
        appSecret:@"5b8523e0e9d02aaeec7f4376fd8601609c8ea6426a8ed333efb3a6077699374c"
      callbackUrl:@"ios://authcode"];
    [FYX startService:self];
    
    [super viewDidLoad];
    //restore from persistent memory
    
    self.progressBar.progress = 0;
    
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
    
    //Initialize location manager
    //@"37.732015,-122.432492";//@"25 Rousseau Street, San Francisco, CA";//@"101 Bayshore Boulevard, San Francisco, CA 94124";
	manager = [[CLLocationManager alloc] init];
    manager.delegate = self;
    manager.desiredAccuracy = kCLLocationAccuracyBest; //try best for navigation!
    geocoder = [[CLGeocoder alloc] init];
    [manager startUpdatingLocation];
    
    /*
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:tap];
     */
    NSLog(@"started FOR THE FIRST TIME stored data: %@ %@ %f %f", idname, destination, destinationLat, destinationLon);
    
}

- (void)serviceStarted
{
    NSLog(@"#########Proximity service started!");
    
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"fyx_service_started_key"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    self.transmitters = [NSMutableArray new];
    
    self.visitManager = [[FYXVisitManager alloc] init];
    self.visitManager.delegate = self;
    
    [self.visitManager startWithOptions:@{FYXVisitOptionDepartureIntervalInSecondsKey:@15,
                                          FYXSightingOptionSignalStrengthWindowKey:@(FYXSightingOptionSignalStrengthWindowNone)}];
}

- (void)receivedSighting:(FYXVisit *)visit updateTime:(NSDate *)updateTime RSSI:(NSNumber *)RSSI
{
    //NSLog(@" %@ %@ %@", RSSI, visit.transmitter.battery, visit.transmitter.temperature);
    
    //NSLog(@" %@ RSSI %@",[visit.transmitter.name substringToIndex:2], RSSI);

    //if([visit.transmitter.name isEqualToString:@"B2"]){
    NSString *theInfo = [NSString stringWithFormat: @"%@ %@ %@ %@",
                         [visit.transmitter.name substringToIndex:2], //for B1 which is longer.
                         RSSI,
                         visit.transmitter.battery,
                         visit.transmitter.temperature];
    
    
    
     //NSLog(@"%@", theInfo);
    if([RSSI floatValue] > -55.0f){
        //NSLog(@"Here in -60");
        if ([visit.transmitter.name rangeOfString:@"B1"].location != NSNotFound){
            if(self.progressBar.progress < 1/3.0f){
                NSLog(@" %@ RSSI %@",[visit.transmitter.name substringToIndex:2], RSSI);
                self.btAirport.text = @"Ticket Checked";
                self.progressBar.progress = 1/3.0f;
                [self checkInPassegerOnServer:@"1"];
            }
        }
        
        if ([visit.transmitter.name rangeOfString:@"B2"].location != NSNotFound){
            if(self.progressBar.progress < 2/3.0f){
                NSLog(@" %@ RSSI %@",[visit.transmitter.name substringToIndex:2], RSSI);
                self.progressBar.progress = 2/3.0f;
                self.btAirport.text = @"Passed Security";
                [self checkInPassegerOnServer:@"2"];
            }
        }
        
        if ([visit.transmitter.name rangeOfString:@"B3"].location != NSNotFound){
            if(self.progressBar.progress < 1/1.0f){
                NSLog(@" %@ RSSI %@",[visit.transmitter.name substringToIndex:2], RSSI);
                self.btAirport.text = @"At Gate";
                self.progressBar.progress = 3/3.0f;
                [self checkInPassegerOnServer:@"3"];
            }
        }
    }
    
    
}

- (void) checkInPassegerOnServer: (NSString *) fence
{
    NSNumber *date = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
    // time = [NSlong numberWithDouble:[date doubleValue]*1000.0];
    double time = [date doubleValue]*1000.0;
    NSMutableURLRequest *theRequest=[NSMutableURLRequest
                                     requestWithURL:[NSURL URLWithString:checkInURL]
                                     cachePolicy:NSURLRequestUseProtocolCachePolicy
                                     timeoutInterval:60.0];
    NSString *name=[NSString stringWithFormat:@"'%@'",idname];
    NSString* data = @"empty";
    data = [NSString stringWithFormat: @"id=%@&time=%.0f&locationid=%@",name,time,fence]; //float 1411506503680
    //NSLog(@"sending... %@",data);                                                       double  1411506541520
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








//////// non beacon methods



- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    //Called every time something is typed in the search box
    //NSLog(@"searchText: %@    scope: %@", searchText, scope);
    //[searchResults addObject: searchText];
    //[self.sdController.searchResultsTableView reloadData];
    //NSLog(@"filter, after getDistination: %@: %@",searchText, searchResults);
    [self getDestination:searchText];
}


-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    //called everytime search is entered
    [self filterContentForSearchText:searchString scope:[[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    return YES;
}

//search view table
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    //tells table how large to be based on search results array
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
    // Display recipe in the table cell
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
   
    NSLog(@">>>%@ %f %f", destination, destinationLat,destinationLon);
    [self.searchDisplayController setActive:NO];
    [self.searchBar resignFirstResponder];
    [self.searchBar setText:destination];
    self.status.text = @"";
}

//saving idname from text field
- (BOOL)textFieldShouldReturn:(UITextField *)textField { //is there another way to save?
    if (textField == self.idNameTextField) {
        [textField resignFirstResponder];
        idname = self.idNameTextField.text;
       
        //saving to persistent memory
        [[NSUserDefaults standardUserDefaults] setObject:idname forKey:@"idname"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        NSLog(@"name entered: %@", idname);
        return NO;
    }
    return YES;
}

-(void):(UIScrollView *)scrollView
{
    [self.view endEditing:YES];
}

- (IBAction)idEntered:(id)sender {
    idname = self.idNameTextField.text;
    self.status.text = @"";
}

//button that starts transmitting
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
            stopped= !stopped;
            return;
        }
        //starting transmission with correct variables
        startup = NO;
        [manager startUpdatingLocation];
        NSLog(@"starting update");
        self.status.text = @"transmitting";
        [self.transmitButton setTitle:@"Stop" forState:(UIControlStateNormal)];
        [self getDestination:@""];
    } else {
        //stop button hit
        [manager stopUpdatingLocation];
        NSLog(@"stopping update");
        self.status.text = @"stopped";
        [self.transmitButton setTitle:@"Transmit Location" forState:(UIControlStateNormal)];
        
    }
}
//init
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        stopped = true;
    }
    return self;
}

-(void)dismissKeyboard {
    if(![self.idNameTextField.text isEqualToString: @""]){
        [self.idNameTextField resignFirstResponder];
        idname = self.idNameTextField.text;
        NSLog(@"name entered: %@", idname);
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - CLLocationManagerDelegate Methods

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"Error: %@", error);
    NSLog(@"Failed to get location! :(");
}

/*
 //*/


//gets addresses from search string from apple
- (void)getDestination: (NSString *) text
{
    __block NSMutableArray *temp = [[NSMutableArray alloc] init];
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
    //return temp;
}

/*
 - (NSArray *)getDestination: (NSString *) text
 {
 NSMutableArray *temp = [[NSMutableArray alloc] init];
 [temp addObject:@"heyoooo"];
 NSLog(@"%@ %@", @"gettingDestination:", idname);
 NSString *address =@"";
 
 
 [geocoder geocodeAddressString:text completionHandler:^(NSArray* placemarks, NSError* error){
 NSLog(@"gettingDestination: # of placemarks %d", [placemarks count]);
 for (CLPlacemark* aPlacemark in placemarks)
 {
 for (NSString *key in aPlacemark.addressDictionary){
 //NSLog(@"gettingDestination: key %@ value %@",key,[aPlacemark.addressDictionary valueForKey:key]);
 }
 //NSLog(@"aPlacemark.addressDictionary: %@", [aPlacemark.addressDictionary valueForKey:@"FormattedAddressLines"][1]);
 NSArray *adArr = [aPlacemark.addressDictionary valueForKey:@"FormattedAddressLines"];
 if([[aPlacemark.addressDictionary valueForKey:@"FormattedAddressLines"] count]==3){
 address = [NSString stringWithFormat:@"%@, %@",
 [aPlacemark.addressDictionary valueForKey:@"FormattedAddressLines"][0],
 [aPlacemark.addressDictionary valueForKey:@"FormattedAddressLines"][1]
 //[aPlacemark.addressDictionary valueForKey:@"FormattedAddressLines"][2]
 ];
 NSLog(@"address %@",address);
 
 [temp addObject:[NSString stringWithFormat:@"%@, %@", adArr[0], adArr[1]]];
 }
 
 }
 }];
 
 NSLog(@"%@ %@", @"**************return gettingDestination:", temp);
 NSLog(@"%@", @"after");
 return temp;
 }
 */

//gets route from google
- (void)getRoute
{
    NSNumber *time = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
    //make sure we don't send multiple requests
    if(time.doubleValue - timeOfLastUpload >= gpsInterval-2){
        
        NSString *url = [NSString stringWithFormat: @"http://maps.googleapis.com/maps/api/directions/json?origin=%f,%f&destination=%f,%f&sensor=true&mode=%@",currentLat,currentLon,destinationLat,destinationLon,@"driving"]; //Tell huu about sensor //metric //mode?
        
        NSLog(@"requesting location from google..");
        NSMutableURLRequest *theRequest=[NSMutableURLRequest
                                         requestWithURL:[NSURL URLWithString:url]
                                         cachePolicy:NSURLRequestUseProtocolCachePolicy
                                         timeoutInterval:60.0];
        [theRequest setHTTPMethod:@"GET"];
        [theRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        //routeStr + point.latitude + "," + point.longitude + "|";
        //NSURLConnection *con = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
        NSError *error;
        NSURLResponse *response;
        //NSString* str = @"teststring";
        NSData * data;// = [str dataUsingEncoding:NSUTF8StringEncoding];
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
            //NSLog(@"encoded: %@", polyEncoded);
            //NSLog(@"decoded after: %@", polyDecoded);
            NSArray *legsArr = [route valueForKey:@"legs"];
            NSDictionary *leg = legsArr[0];
            NSDictionary *duration = [leg valueForKey:@"duration"];
            NSString *valueInSec = [duration valueForKey:@"value"];
            /*
            //NSLog(@"the value in seconds: %@", valueInSec);
             NSArray *steps = [leg valueForKey:@"steps"];
            //NSLog(@"%@", @"steps:::::::::");
            //for (NSString *key in leg) {
                //NSLog(@"key %@", key);
                //NSLog(@"key %@ value %@",key,[tempDic valueForKey:key]);
            //}
            //for (NSString *key in route) {
                //NSLog(@"key %@", key);
                //NSLog(@"key %@ value %@",key,[tempDic valueForKey:key]);
            //}
            for (NSDictionary *tempDic in steps) {
                for (NSString *key in tempDic) {
                    //NSLog(@"steps key %@", key);
                    //NSLog(@"key %@ value %@",key,[tempDic valueForKey:key]);
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

//decodes route object from google
- (NSMutableString *)decodePoly: (NSString *) encoded
{
    NSMutableString *poly = [[NSMutableString alloc] init];//init  = new ArrayList<LatLng>();
    int index = 0;
    int len = [encoded length];
    int lat = 0, lng = 0;
    int counter = 0;
    while (index < len) {
        counter++;
        int b, shift = 0, result = 0;
        do {
            b = [encoded characterAtIndex:index++] - 63;
            result |= (b & 0x1f) << shift;
            shift += 5;
        } while (b >= 0x20);
        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;
        shift = 0;
        result = 0;
        do {
            b = [encoded characterAtIndex:index++] - 63;
            result |= (b & 0x1f) << shift;
            shift += 5;
        } while (b >= 0x20);
        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;
        //LatLng position = new LatLng((double) lat / 1E5, (double) lng / 1E5);
        double latf = lat / 1E5;
        double lonf = lng / 1E5;
        if ((counter % 5) == 0) {
            NSString * temp = [NSString stringWithFormat:@"%f,%f|",latf, lonf];
            [poly appendString:temp];
        }
        else {
            continue;
        }
        
    }
    return poly;
}


//uploads to Amazon
- (void) sendToServer: (NSString *) route eta: (NSString *) eta
{
    NSNumber *time = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
    time = [NSNumber numberWithDouble:[time doubleValue]*1000.0];
    NSString *lat=[NSString stringWithFormat:@"%.10f",currentLat];
    //NSLog(@"currentLat %f lat %@",currentLat, lat);
    NSString *lon=[NSString stringWithFormat:@"%.10f",currentLon];
    NSString *dlat=[NSString stringWithFormat:@"%.10f",destinationLat];
    NSString *dlon=[NSString stringWithFormat:@"%.10f",destinationLon];
    NSString *name=[NSString stringWithFormat:@"'%@'",idname];
    if(getETA)route = [NSString stringWithFormat:@"'%@'",route];
    //NSMutableData* _receivedData;
    //route = @"placeholder";
    //NSString *url = [NSString stringWithFormat: @"%@?id=%@&time=%@&latitude=%@&longitude=%@&route=%@&eta=%@",serverUrl,idname,time,lat,lon,route,eta]; // //route=%@&
    NSLog(@"sending to server: %@",addCrewURL);
    NSMutableURLRequest *theRequest=[NSMutableURLRequest
                                     requestWithURL:[NSURL URLWithString:addCrewURL]
                                     cachePolicy:NSURLRequestUseProtocolCachePolicy
                                     timeoutInterval:60.0];
    /*
     NSLog(@"%@",idname);
     NSLog(@"%@",time);
     NSLog(@"%@",lat);
     NSLog(@"%@",lon);
     NSLog(@"%@",route);
     NSLog(@"%@",eta);
     */
     NSString* data = @"empty";
    if(getETA){
        data = [NSString stringWithFormat: @"id=%@&time=%@&latitude=%@&longitude=%@&route=%@&eta=%@",name,time,lat,lon,route,eta];
    } else {
        data = [NSString stringWithFormat: @"id=%@&time=%@&lat=%@&lon=%@&destlat=%@&destlon=%@",name,time,lat,lon,dlat,dlon];
    }
    //NSLog(@"lat %@ lon %@ eta %@", lat, lon, eta);
   // NSLog(@"%@ sending str %@", idname, [NSString stringWithFormat: @"id=%@&time=%@&latitude=%@&longitude=%@&route=%@&eta=%@",name,time,lat,lon,@"...",eta]);
    NSLog(@"sending... %@",data);
    NSData* strData = [data dataUsingEncoding:NSUTF8StringEncoding];
    //NSDictionary* jsonDictionary = @{@"id":idname,@"time":time,@"latitude":lat,@"longitude":lon,@"route":route,@"eta":eta};
    //NSError *error;
    //NSData* jsonData = [NSJSONSerialization dataWithJSONObject:jsonDictionary options:NSJSONWritingPrettyPrinted error:&error];
    //NSData* httpData = [NS dataWithJSONObject:jsonDictionary options:NSJSONWritingPrettyPrinted error:&error];
    [theRequest setHTTPMethod:@"POST"];
    [theRequest setHTTPBody:strData];
    //[theRequest setHTTPBody:jsonData];
    //[theRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"]; charset=utf-8
    [theRequest addValue:@"utf-8" forHTTPHeaderField:@"charset"];
    NSURLConnection *con = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
    if (con) {
        //_receivedData=[theRequest ];
        NSLog(@"%@ successfully uploaded to server", idname);
    } else {
        NSLog(@"%@",@"!!!!!!!!!!!!!!!!!!!!!!!!!!connection error to server");
    }
}


- (void)locationManagerDidPauseLocationUpdates:(CLLocationManager *)manager
{
    NSLog(@"paused!!!!!!!!!!!!!!!!!!!!!");
}

//starts location update loop everytime gps hardware gets a new location
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    
    //NSLog(@"Location: %@", newLocation);
    CLLocation *currentLocation = newLocation;
    if (currentLocation != nil) {
        //timer = nil;
        //[NSString stringWithFormat:@"%.8f",
        
        NSLog(@"didUpdateToLocation new lat: %.10f lon: %.10f",currentLocation.coordinate.latitude, currentLocation.coordinate.longitude);
        
        currentLat = currentLocation.coordinate.latitude;
        currentLon = currentLocation.coordinate.longitude;
        NSLog(@"didUpdateToLocation cur lat: %.10f lon: %.10f lat %.10f",currentLat, currentLat, currentLocation.coordinate.latitude);

        //NSLOG("%f ");
        //region = currentLocation;
        //starts timer to get location again in set sumber of seconds (gpsInterval)
        if([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive){
            [manager stopUpdatingLocation];
            timer = [NSTimer scheduledTimerWithTimeInterval:gpsInterval target:self selector:@selector(_turnOnLocationManager)  userInfo:nil repeats:NO];
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
        //NSLog(@"here did");
        //get route send to server
        if(getETA) {
            if(!startup)[self getRoute];
        } else {
            if(!startup)[self sendToServer:@"-1" eta:@"-1"];
        }

    }
}

- (void)setLocationBackToNormal
{
    NSLog(@"came back FROM background");
    //[manager stopMonitoringSignificantLocationChanges];
}

//get's location in the background
- (void)getBGLocation
{
    NSLog(@"starting background location");
    [[NSUserDefaults standardUserDefaults] synchronize]; //help keep data persistent(?)
    if(!stopped){
        manager = [[CLLocationManager alloc] init];
        manager.delegate = self;
        manager.desiredAccuracy = kCLLocationAccuracyBest; //try best for navigation!
        geocoder = [[CLGeocoder alloc] init];
        //[manager startUpdatingLocation];
        [manager startMonitoringSignificantLocationChanges];
        [self _turnOnLocationManager];
    }
}

- (void)_turnOnLocationManager {
    if(!stopped)[manager startUpdatingLocation];
}

@end
