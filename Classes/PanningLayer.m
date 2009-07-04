/*
 * This file is part of Gorillas.
 *
 *  Gorillas is open software: you can use or modify it under the
 *  terms of the Java Research License or optionally a more
 *  permissive Commercial License.
 *
 *  Gorillas is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 *  You should have received a copy of the Java Research License
 *  along with Gorillas in the file named 'COPYING'.
 *  If not, see <http://stuff.lhunath.com/COPYING>.
 */

//
//  PanningLayer.m
//  Gorillas
//
//  Created by Maarten Billemont on 15/02/09.
//  Copyright, lhunath (Maarten Billemont) 2008. All rights reserved.
//

#import "PanningLayer.h"
#import "GorillasAppDelegate.h"


@implementation PanningLayer


-(id) init {
    
    if (!(self = [super init]))
		return self;
    
    isTouchEnabled  = YES;
    initialDist    = -1;
    
    return self;
}


-(void) reset {

    if ([self scale] != 1) {
        if (scaleAction) {
            [self stopAction:scaleAction];
            [scaleAction release];
        }
        
        [self runAction:scaleAction = [[ScaleTo alloc] initWithDuration:[[GorillasConfig get] transitionDuration]
                                                                  scale:1]];
    }
}


-(BOOL) ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if([[event allTouches] count] != 2)
        return [self ccTouchesCancelled:touches withEvent:event];
    
    NSArray *touchesArray = [[event allTouches] allObjects];
    UITouch *from = [touchesArray objectAtIndex:0];
    UITouch *to = [touchesArray objectAtIndex:1];
    CGPoint pFrom = [from locationInView: [from view]];
    CGPoint pTo = [to locationInView: [to view]];
    
    initialScale = [self scale];
    initialDist = fabsf(pFrom.y - pTo.y);
    
    return kEventHandled;
}


-(BOOL) ccTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if([[event allTouches] count] != 2)
        return [self ccTouchesCancelled:touches withEvent:event];

    if(initialDist < 0)
        return [self ccTouchesBegan:touches withEvent:event];
    
    NSArray *touchesArray = [[event allTouches] allObjects];
    UITouch *from = [touchesArray objectAtIndex:0];
    UITouch *to = [touchesArray objectAtIndex:1];
    CGPoint pFrom = [from locationInView: [from view]];
    CGPoint pTo = [to locationInView: [to view]];

    CGFloat newDist = fabsf(pFrom.y - pTo.y);
    CGFloat newScale = initialScale * (newDist / initialDist);
    CGFloat limitedScale = fmaxf(fminf(newScale, 1.1f), 0.8f);
    if(limitedScale != newScale) {
        newScale = limitedScale;
        initialDist = newDist;
        initialScale = newScale;
    }

    [self scaleTo:newScale limited:YES];
    
    return kEventHandled;
}


-(BOOL) ccTouchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {

    if(initialDist < 0)
        return kEventIgnored;
    
    [self setScale:initialScale];
    initialDist = -1;
    
    return kEventHandled;
}


-(BOOL) ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if(initialDist < 0)
        return kEventIgnored;
    
    initialDist = -1;
    
    return kEventHandled;
}


-(void) scaleTo:(CGFloat)newScale {

    [self scaleTo:newScale limited:NO];
}


-(void) scaleTo:(CGFloat)newScale limited:(BOOL)limited {

    if (limited)
        newScale = fmaxf(fminf(newScale, 1.1f), 0.8f);

    CGFloat duration = [GorillasConfig get].transitionDuration;
    if(scaleAction != nil && ![scaleAction isDone]) {
        duration -= [scaleAction elapsed];
        [self stopAction:scaleAction];
    }
    [scaleAction release];
    [self runAction:scaleAction = [[ScaleTo alloc] initWithDuration:duration
                                                              scale:newScale]];
}


-(void) scrollToCenter:(CGPoint)r horizontal:(BOOL)horizontal {
    
    CGSize winSize = [Director sharedDirector].winSize;
    
    // Figure out where the buildings start and end.
    // Use that for camera limits, take scaling into account.
    float min = [[GorillasAppDelegate get].gameLayer.cityLayer left];
    float max = [[GorillasAppDelegate get].gameLayer.cityLayer right];
    float top = winSize.height * 2;
    CGFloat _scale = self.scale;
    r = ccpMult(r, _scale);
    min *= _scale;
    max *= _scale;
    top *= _scale;
    
    if(horizontal) {
        r = ccp(fmaxf(fminf(r.x, max - winSize.width / 2), min + winSize.width / 2),
                fmaxf(fminf(r.y, top - winSize.height / 2), winSize.height / 2));
    }
    
    else {
        r.x = winSize.width / 2;
        if(r.y < winSize.height * 0.8f)
            r.y = winSize.height / 2;
    }
    
    // Stop the current scroll.
    ccTime scrollActionElapsed = [scrollAction isDone]? 0: scrollAction.elapsed;
    if(scrollAction)
        [self stopAction: scrollAction];
    [scrollAction release];
    
    // Start a new scroll with an updated destination point.
    CGPoint g = ccp(winSize.width / 2 - r.x, winSize.height / 2 - r.y);
    
    // Scroll to current point should take initial duration minus what has already elapsed to scroll to approach previous points.
    if(scrollActionElapsed < [[GorillasConfig get] gameScrollDuration])
        [self runAction:(scrollAction = [[MoveTo alloc] initWithDuration:[[GorillasConfig get] gameScrollDuration] - scrollActionElapsed
                                                                position:g])];
    else {
        scrollAction = nil;
        self.position = g;
    }
}


-(void) dealloc {
    
    [scrollAction release];
    scrollAction = nil;
    
    [scaleAction release];
    scaleAction = nil;
    
    [super dealloc];
}


@end
