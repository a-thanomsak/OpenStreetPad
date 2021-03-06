//
//  Ruleset.m
//  OpenStreetPad
//
//  Created by Thomas Davie on 02/11/2011.
//  Copyright (c) 2011 Thomas Davie. All rights reserved.
//

#import "OSPMapCSSRuleset.h"

#import "OSPMapCSSRule.h"
#import "OSPMapCSSImport.h"
#import "OSPMapCSSSubselector.h"
#import "OSPMapCSSDeclaration.h"
#import "OSPMapCSSStyle.h"

#import "OSPMapCSSSelector.h"

#import "OSPMapCSSParser.h"

@implementation OSPMapCSSRuleset

@synthesize rules;

- (id)initWithSyntaxTree:(CPSyntaxTree *)syntaxTree
{
    self = [super init];
    
    if (nil != self)
    {
        [self setRules:[[syntaxTree children] objectAtIndex:0]];
    }
    
    return self;
}

- (void)deleteMetaAndLoadImportsRelativeToURL:(NSURL *)baseURL
{
    NSMutableArray *newRules = [[self rules] mutableCopy];
    OSPMapCSSParser *parser = [[OSPMapCSSParser alloc] init];
    
    for (id rule in [self rules])
    {
        if ([rule isKindOfClass:[OSPMapCSSImport class]])
        {
            OSPMapCSSImport *import = rule;
            NSURL *completeURL = [NSURL URLWithString:[import url] relativeToURL:baseURL];
            if (nil != completeURL)
            {
                OSPMapCSSStyleSheet *stylesheet = [parser parse:[NSString stringWithContentsOfURL:completeURL encoding:NSUTF8StringEncoding error:NULL]];
                [stylesheet deleteMetaAndLoadImportsRelativeToURL:[completeURL URLByDeletingLastPathComponent]];
                for (OSPMapCSSRule *importedRule in [[stylesheet ruleset] rules])
                {
                    [newRules addObject:importedRule];
                }
            }
        }
        else if (![rule isOnlyMeta])
        {
            [newRules addObject:rule];
        }
    }
    
    [self setRules:newRules];
}

- (NSString *)description
{
    NSMutableString *ruleset = [NSMutableString string];
    
    for (id rule in [self rules])
    {
        [ruleset appendFormat:@"%@\n", rule];
    }
    
    return ruleset;
}

- (NSDictionary *)applyToObject:(OSPAPIObject *)object atZoom:(float)zoom
{
    NSMutableDictionary *styles = [NSMutableDictionary dictionary];
    for (id rule in [self rules])
    {
        if ([rule isKindOfClass:[OSPMapCSSRule class]])
        {
            BOOL stop = NO;
            NSDictionary *ruleStyles = [rule applyToObject:object atZoom:zoom stop:&stop];
            
            for (NSString *layerIdentifier in ruleStyles)
            {
                NSMutableDictionary *currentStyle = [styles objectForKey:layerIdentifier];
                NSDictionary *style = [ruleStyles objectForKey:layerIdentifier];
                
                if (nil == currentStyle)
                {
                    if ([layerIdentifier isEqualToString:@"*"])
                    {
                        [styles setObject:[style mutableCopy] forKey:layerIdentifier];
                    }
                    else
                    {
                        currentStyle = [[styles objectForKey:@"*"] mutableCopy];
                        if (nil == currentStyle)
                        {
                            currentStyle = [style mutableCopy];
                        }
                        else
                        {
                            [currentStyle addEntriesFromDictionary:style];
                        }
                        [styles setObject:currentStyle forKey:layerIdentifier];
                    }
                }
                else
                {
                    [currentStyle addEntriesFromDictionary:style];
                }
                
                if ([layerIdentifier isEqualToString:@"*"])
                {
                    for (NSString *existingLayerIdentifier in styles)
                    {
                        if (![existingLayerIdentifier isEqualToString:@"*"])
                        {
                            currentStyle = [styles objectForKey:existingLayerIdentifier];
                            [currentStyle addEntriesFromDictionary:style];
                        }
                    }
                }
            }
            
            if (stop)
            {
                return styles;
            }
        }
    }
    return styles;
}

- (NSDictionary *)styleForCanvasAtZoom:(float)zoom
{
    for (id rule in [self rules])
    {
        if ([rule isKindOfClass:[OSPMapCSSRule class]])
        {
            BOOL matches = NO;
            for (OSPMapCSSSelector *selector in [rule selectors])
            {
                if ([[selector subselectors] count] == 1)
                {
                    OSPMapCSSSubselector *subSelector = [[selector subselectors] objectAtIndex:0];
                    if ([subSelector objectType] == OSPMapCSSObjectTypeCanvas && [subSelector zoomIsInRange:zoom])
                    {
                        matches = YES;
                    }
                }
            }
            
            if (matches)
            {
                NSMutableDictionary *style = [[NSMutableDictionary alloc] init];
                for (OSPMapCSSDeclaration *decl in [rule declarations])
                {
                    for (OSPMapCSSStyle *st in [decl styles])
                    {
                        [style setObject:[st specifiers] forKey:[[st key] description]];
                    }
                }
                return [style copy];
            }
        }
    }
    return [NSDictionary dictionary];
}

@end
