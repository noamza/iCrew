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

@interface NZAMainViewController () <CLLocationManagerDelegate, UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UIButton *transmitButton; //comment
@property (weak, nonatomic) IBOutlet UILabel *status;
@property (weak, nonatomic) IBOutlet UITextField *idNameTextField;
@property (strong, nonatomic) IBOutlet UISearchDisplayController *sdController;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (weak, nonatomic) IBOutlet MKMapView *map;

@end

@implementation NZAMainViewController

//NSString *serverUrl = @"http://ec2-54-200-25-136.us-west-2.compute.amazonaws.com/n.php";
NSString *serverUrl = @"http://ec2-54-200-25-136.us-west-2.compute.amazonaws.com/test.php";
CLLocationManager *manager;
CLGeocoder *geocoder;
CLPlacemark *placemark;
BOOL stopped = true;
bool startup = true;
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
    [super viewDidLoad];
    //restore from persistent memory
    idname = [[NSUserDefaults standardUserDefaults] stringForKey:@"idname"];
    self.idNameTextField.text = idname;
    destination = [[NSUserDefaults standardUserDefaults] stringForKey:@"destination"];
    if(destination == nil) {
        self.searchBar.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"destination"];
    } else {
        self.searchBar.text = destination;
        destinationLat = [[NSUserDefaults standardUserDefaults] doubleForKey:@"destinationLat"];
        destinationLon = [[NSUserDefaults standardUserDefaults] doubleForKey:@"destinationLon"];
    }
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


- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    //NSLog(@"searchText: %@    scope: %@", searchText, scope);
    [self getDestination:searchText];
    //[searchResults addObject: searchText];
    //[self.sdController.searchResultsTableView reloadData];
    //NSLog(@"filter, after getDistination: %@: %@",searchText, searchResults);
}


-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterContentForSearchText:searchString scope:[[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:
        [self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    return YES;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [searchResults count];
}

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

//getting destionation from search results table
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
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
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
        //[self getRoute];
        //[self sendToServer];
        //[self sendTo];
    } else {
        //stop button hit
        [manager stopUpdatingLocation];
        NSLog(@"stopping update");
        self.status.text = @"stopped";
        [self.transmitButton setTitle:@"Transmit Location" forState:(UIControlStateNormal)];
        
    }
}

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


- (void)getDestination: (NSString *) text
{
    __block NSMutableArray *temp = [[NSMutableArray alloc] init];
    [geocoder geocodeAddressString:text inRegion:region completionHandler:^(NSArray* placemarks, NSError* error){
        //NSLog(@"gettingDestination: # of placemarks %d", [placemarks count]);
        for (CLPlacemark* aPlacemark in placemarks)
        {
            for (NSString *key in aPlacemark.addressDictionary){
            }
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
                NSLog(@"no poly to draw!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                polyDecoded = @"";
            }
            //NSLog(@"encoded: %@", polyEncoded);
            //NSLog(@"decoded after: %@", polyDecoded);
            NSArray *legsArr = [route valueForKey:@"legs"];
            NSDictionary *leg = legsArr[0];
            NSDictionary *duration = [leg valueForKey:@"duration"];
            NSString *valueInSec = [duration valueForKey:@"value"];
            //NSLog(@"the value in seconds: %@", valueInSec);
            NSArray *steps = [leg valueForKey:@"steps"];
            //NSLog(@"%@", @"steps:::::::::");
            for (NSString *key in leg) {
                //NSLog(@"key %@", key);
                //NSLog(@"key %@ value %@",key,[tempDic valueForKey:key]);
            }
            for (NSString *key in route) {
                //NSLog(@"key %@", key);
                //NSLog(@"key %@ value %@",key,[tempDic valueForKey:key]);
            }
            for (NSDictionary *tempDic in steps) {
                for (NSString *key in tempDic) {
                    //NSLog(@"steps key %@", key);
                    //NSLog(@"key %@ value %@",key,[tempDic valueForKey:key]);
                }
                
            }
            timeOfLastUpload = time.doubleValue;
            NSLog(@"successfully received data from google");
            [self sendToServer:polyDecoded eta:valueInSec];
        } else {
            NSLog(@"google returned nothing, those bastards !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
            [self getRoute];
        }
    }
    
}

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



- (void) sendToServer: (NSString *) route eta: (NSString *) eta
{
    NSNumber *time = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
    time = [NSNumber numberWithDouble:[time doubleValue]*1000.0];
    NSString *lat=[NSString stringWithFormat:@"%.10f",currentLat];
    //NSLog(@"currentLat %f lat %@",currentLat, lat);
    NSString *lon=[NSString stringWithFormat:@"%.10f",currentLon];
    NSString *name=[NSString stringWithFormat:@"'%@'",idname];
    route = [NSString stringWithFormat:@"'%@'",route];
    //NSMutableData* _receivedData;
    //route = @"placeholder";
    //NSString *url = [NSString stringWithFormat: @"%@?id=%@&time=%@&latitude=%@&longitude=%@&route=%@&eta=%@",serverUrl,idname,time,lat,lon,route,eta]; // //route=%@&
    NSLog(@"sending to server: %@",serverUrl);
    NSMutableURLRequest *theRequest=[NSMutableURLRequest
                                     requestWithURL:[NSURL URLWithString:serverUrl]
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
    NSString* str = [NSString stringWithFormat: @"id=%@&time=%@&latitude=%@&longitude=%@&route=%@&eta=%@",name,time,lat,lon,route,eta];
    NSLog(@"lat %@ lon %@ eta %@", lat, lon, eta);
   // NSLog(@"%@ sending str %@", idname, [NSString stringWithFormat: @"id=%@&time=%@&latitude=%@&longitude=%@&route=%@&eta=%@",name,time,lat,lon,@"...",eta]);
    NSData* strData = [str dataUsingEncoding:NSUTF8StringEncoding];
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
        if(!startup)[self getRoute];
        
    }
    
    
}

- (void)setLocationBackToNormal
{
    NSLog(@"came back FROM background");
    //[manager stopMonitoringSignificantLocationChanges];
}

- (void)getBGLocation
{
    NSLog(@"starting background location");
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
