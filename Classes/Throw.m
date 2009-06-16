/*
 * This file is part of Gorillas.
 *
 *  Gorillas is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  Gorillas is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Gorillas in the file named 'COPYING'.
 *  If not, see <http://www.gnu.org/licenses/>.
 */

//
//  Throw.m
//  Gorillas
//
//  Created by Maarten Billemont on 22/11/08.
//  Copyright 2008-2009, lhunath (Maarten Billemont). All rights reserved.
//

#import "Throw.h"
#import "ThrowController.h"
#import "GorillasAppDelegate.h"
#define maxDiff 4
#define recapTime 3


@interface Throw (Private)

-(void) throwEnded;

@end


@implementation Throw

@synthesize recap;//, focussed;


+(Throw *) actionWithVelocity: (cpVect)velocity startPos: (cpVect)startPos {
    
    return [[[Throw alloc] initWithVelocity: velocity startPos: startPos] autorelease];
}


-(Throw *) initWithVelocity: (cpVect)velocity startPos: (cpVect)startPos {
    
    v = velocity;
    r0 = startPos;
    float g = [[GorillasConfig get] gravity];
    
    ccTime t = (v.y + (float) sqrt(v.y * v.y + 2.0f * g * r0.y)) / g;

    if(!(self = [super initWithDuration:t]))
        return self;
    
    recap = 0;
    
    smoke = [[ParticleMeteor alloc] init];
    [smoke setGravity:cpvzero];
    [smoke setPosition:cpvzero];
    [smoke setSpeed:5];
    [smoke setAngle:-90];
    [smoke setAngleVar:10];
    [smoke setLife:3];
    [smoke setEmissionRate:0];
    ccColorF startColor;
	startColor.r = 0.1f;
	startColor.g = 0.2f;
	startColor.b = 0.3f;
    startColor.a = 0.5f;
    [smoke setStartColor:startColor];
    ccColorF endColor;
	endColor.r = 0.0f;
	endColor.g = 0.0f;
	endColor.b = 0.0f;
    endColor.a = 0.3f;
    [smoke setEndColor:endColor];
    
    return self;
}


-(void) start {
    
    running = YES;
    skipped = NO;
    [super start];
    
    if(spinAction) {
        [target stopAction:spinAction];
        [spinAction release];
    }
    
    [target runAction:
     [spinAction = [Repeat actionWithAction:[RotateBy actionWithDuration:1
                                                                   angle:360]
                                      times:(int)duration + 1] retain]];
    [target setVisible:YES];
    [target setTag:GorillasTagBananaFlying];
    
    
    [[[[GorillasAppDelegate get] gameLayer] windLayer] registerSystem:smoke affectAngle:NO];
    
    if([[GorillasConfig get] visualFx]) {
        [smoke setEmissionRate:30];
        [smoke setSize:15.0f * [target scale]];
        [smoke setSizeVar:5.0f * [target scale]];
        if(![smoke parent])
            [target.parent addChild:smoke];
        else
            [smoke resetSystem];
    }
}


-(void) update: (ccTime) dt {

    if(!running)
        // We were stopped.
        return;

    GameLayer *gameLayer = [[GorillasAppDelegate get] gameLayer];
    BuildingsLayer *buildingsLayer = [gameLayer buildingsLayer];
    CGSize winSize = [[Director sharedDirector] winSize];
    
    // Wind influence.
    float w = [[gameLayer windLayer] wind];
    
    // Calculate banana position.
    float g = [[GorillasConfig get] gravity];
    ccTime t = elapsed;
    cpVect r = cpv((v.x + w * t * [[GorillasConfig get] windModifier]) * t + r0.x,
                   v.y * t - t * t * g / 2 + r0.y);

    // Calculate the step size.
    cpVect rTest = [target position];
    cpVect dr = cpvsub(r, rTest);
    float drLen = cpvlength(dr);
    int step = 0, stepCount = drLen <= maxDiff? 1: (int) (drLen / maxDiff) + 1;
    cpVect rStep = stepCount == 1? dr: cpvmult(dr, 1.0f / stepCount);
    BOOL offScreen = NO, hitGorilla = NO, hitBuilding = NO;
    
    if(!recap)
        // Only calculate when not recapping.
        do {
            // Increment rTest toward r.
            rTest = cpvadd(rTest, rStep);
            
            float min = [buildingsLayer left];
            float max = [buildingsLayer right];
            float top = winSize.height * 2;
            if([gameLayer.panningLayer position].x == 0) {
                cpFloat scale = [gameLayer.panningLayer scale];
                min = 0;
                max = winSize.width / scale;
            }
            
            // Figure out whether banana went off screen or hit something.
            offScreen   = rTest.x < min || rTest.x > max
                       || rTest.y < 0 || rTest.y > top;
            hitGorilla  = [buildingsLayer hitsGorilla:rTest];
            hitBuilding = [buildingsLayer hitsBuilding:rTest];
        } while(++step < stepCount && !(hitBuilding || hitGorilla || offScreen));

    else
        // Stop recapping when reached recap r.
        if(elapsed >= recap + recapTime) {
            hitGorilla = YES;
            rTest = recapr;
        }
    
    // If it reached the floor, went off screen, or hit something; stop the banana.
    if([self isDone] || offScreen || hitBuilding || hitGorilla) {
        r = rTest;
        
        if ([gameLayer checkGameStillOn] || recap || ![GorillasConfig get].replay/* || !focussed*/) {
            
            // Hitting something causes an explosion.
            if(hitBuilding || hitGorilla)
                [buildingsLayer explodeAt:r isGorilla:hitGorilla];

            if(recap)
                // Gorilla was revived; kill it again.
                [gameLayer.buildingsLayer.hitGorilla killDead];
            [[gameLayer windLayer] unregisterSystem:smoke];
            [smoke setEmissionRate:0];
            [target setVisible:NO];
            running = NO;
            
            // Update game state.
            [gameLayer updateStateHitGorilla:hitGorilla hitBuilding:hitBuilding offScreen:offScreen throwSkill:throwSkill];
            
            if(skipped)
                [self throwEnded];
            
            else
                [buildingsLayer runAction:[Sequence actions:
                                           [DelayTime actionWithDuration:1],
                                           [CallFunc actionWithTarget:self selector:@selector(throwEnded)],
                                           nil]];
        }
        
        else {
            // Game is over but no recap done yet, start a recap.
            [gameLayer.buildingsLayer.bananaLayer setClearedGorilla:NO];
            [gameLayer.buildingsLayer.hitGorilla revive];
            [[GorillasAppDelegate get].hudLayer message:NSLocalizedString(@"message.killreplay", @"Kill Shot Replay") isImportant:YES];
            [[GorillasAppDelegate get].hudLayer setButtonImage:@"skip.png" callback:self :@selector(skip:)];
            recapr = r;
            recap = elapsed - recapTime;
            r = r0;
            
            [self start];
        }
    }
    
    //if(focussed) {
        if(recap && elapsed > recap) {
            [[GorillasAppDelegate get].gameLayer scaleTimeTo:0.5f duration:0.5f];
            [gameLayer.panningLayer scaleTo:1.5f];
            [gameLayer.panningLayer scrollToCenter:r horizontal:YES];
        } else
            [gameLayer.panningLayer scrollToCenter:r horizontal:[GorillasConfig get].followThrow];
    //}

    [target setPosition:r];
    if([[GorillasConfig get] visualFx]) {
        [smoke setAngle:atan2f([smoke source].y - r.y,
                               [smoke source].x - r.x)
                                / (float)M_PI * 180.0f];
        [smoke setSource:r];
    } else if([smoke emissionRate])
        [smoke setEmissionRate:0];
    
    if(running) {
        if(gameLayer.singlePlayer && gameLayer.activeGorilla.human) {
            // Singleplayer game with human turn is still running; update the skill counter.
            throwSkill = elapsed / 10;
            [[[GorillasAppDelegate get] hudLayer] updateHudWithScore:0 skill:throwSkill];
        }
    }
}


-(void) throwEnded {
    
    [[[[GorillasAppDelegate get] gameLayer] windLayer] unregisterSystem:smoke];
    [target stopAction:spinAction];
    
    //if(focussed) {
        [[GorillasAppDelegate get].gameLayer.panningLayer scrollToCenter:cpvzero horizontal:NO];
        [[GorillasAppDelegate get].gameLayer scaleTimeTo:1 duration:0.5f];
    //}

    [[ThrowController get] throwEnded];
}    


-(void) skip: (id) caller {
    
    elapsed = recap + recapTime;
    skipped = YES;
}


-(void) stop {

    duration = 0;
    running = NO;
    
    [[GorillasAppDelegate get].gameLayer.activeGorilla setActive:NO];
    [target setTag:GorillasTagBananaNotFlying];
}


-(BOOL) isDone {

    return [super isDone] || !running;
}


-(void) dealloc {
    
    [smoke release];
    smoke = nil;
    
    [spinAction release];
    spinAction = nil;
    
    [super dealloc];
}


@end
