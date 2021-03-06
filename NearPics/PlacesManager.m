//
//  PlacesManager.m
//  NearPics
//
//  Created by manuMohan on 10/07/13.
//  Copyright (c) 2013 manuMohan. All rights reserved.
//
#define PLACES_URL @"https://maps.googleapis.com/maps/api/place/nearbysearch/json"

#import "PlacesManager.h"
#import "SBJson.h"
static PlacesManager *sharedManager = NULL;

@interface PlacesManager(){
    CLLocation *lastLocation;
    UIAlertView *limitAlert;
}

@end
@implementation PlacesManager

- (id)init{
    self = [super init];
    if(self){
        locationManager = [[CLLocationManager alloc] init];
        locationManager.delegate = self;
        locationManager.distanceFilter = kCLDistanceFilterNone;
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
        [locationManager startUpdatingLocation];
       
    }
    return self;
}
+ (PlacesManager *)sharedInstance{
    if(sharedManager == NULL){
        sharedManager = [[PlacesManager alloc] init];
        
    }
    return sharedManager;
}

- (void)getPlacesNearLat:(NSString *)lat andLong:(NSString *)lon{
    NSString *completeUrl = [NSString stringWithFormat:@"%@?location=%@,%@&radius=%@&sensor=true&key=%@",
                             PLACES_URL,lat,lon,@"1000",PLACES_API_KEY];
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:completeUrl]];
    request.delegate = self;
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [request startAsynchronous];
}
#pragma mark - response parser methods
- (NSArray *)parsePlacesResponse:(NSString *)response{
    SBJsonParser *parser = [[SBJsonParser alloc] init];
    NSDictionary *placesResponse = [parser objectWithString:response];
    NSString *status = [placesResponse objectForKey:@"status"];
    if([status isEqualToString:@"OVER_QUERY_LIMIT"]){
        if([limitAlert isVisible]){
            return nil;
        }
        limitAlert = [[UIAlertView alloc] initWithTitle:@"Limit Reached" message:@"Google places query limit reached. Please try after sometime..." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
        [limitAlert show];
        return nil;
    }
    NSArray *placesJson = [placesResponse objectForKey:@"results"];
    NSMutableArray *places = [[NSMutableArray alloc] init];
    for(NSDictionary *placeJson in placesJson){
        Place *place = [[Place alloc] init];
        place.name = [placeJson valueForKey:@"name"];
        place.address = [placeJson valueForKey:@"formatted_address"];
        NSDictionary *location = [[placeJson valueForKey:@"geometry"] valueForKey:@"location"];
        place.latitude = [NSString stringWithFormat:@"%@",[location valueForKey:@"lat"]];
        place.longitude = [NSString stringWithFormat:@"%@",[location valueForKey:@"lng"]];
        [places addObject:place];
    }
    return [NSArray arrayWithArray:places];
}
#pragma mark - ASIHttp delegate methods
- (void)requestFinished:(ASIHTTPRequest *)request{
    NSArray *places = [self parsePlacesResponse:request.responseString];
	NSLog(@"%@",request.responseString);
    //[self.delegate loadedPlacesWithArray:places];
    [self performSelectorOnMainThread:@selector(callLoadedPlacesWithArray:) withObject:places waitUntilDone:NO];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
}
- (void)requestFailed:(ASIHTTPRequest *)request{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}
- (void)callLoadedPlacesWithArray:(NSArray *)array{
    [self.delegate loadedPlacesWithArray:array];
}

#pragma mark - location manager delegate methods
- (void)locationManager:(CLLocationManager *)manager
	 didUpdateLocations:(NSArray *)locations{
    CLLocation *location = [locations lastObject];
    if(lastLocation != nil){
        CLLocationDistance dist = [lastLocation distanceFromLocation:location];
        if(dist < 100){
            lastLocation = location;
            return;
        }
    }else{
        lastLocation = location;
    }
    NSString *lat = [NSString stringWithFormat:@"%f",location.coordinate.latitude];
    NSString *lon = [NSString stringWithFormat:@"%f",location.coordinate.longitude];
    [self getPlacesNearLat:lat andLong:lon];
}

@end
