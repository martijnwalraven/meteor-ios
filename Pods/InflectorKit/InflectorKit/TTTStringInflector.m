// TTTStringInflector.m
//
// Copyright (c) 2013 Mattt Thompson (http://mattt.me)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "TTTStringInflector.h"

@interface TTTStringInflectionRule : NSObject

+ (instancetype)ruleWithPattern:(NSString *)pattern
                        options:(NSRegularExpressionOptions)options
                    replacement:(NSString *)replacement;

- (NSUInteger)evaluateString:(NSMutableString *)mutableString;

@end

#pragma mark -

@interface TTTStringInflector (Localization)
- (void)addPluralizationRulesForEnUSLocale;
@end

#pragma mark -

@interface TTTStringInflector ()
@property (readwrite, nonatomic, strong) NSMutableArray *mutableSingularRules;
@property (readwrite, nonatomic, strong) NSMutableArray *mutablePluralRules;
@property (readwrite, nonatomic, strong) NSMutableSet *mutableUncountables;
@property (readwrite, nonatomic, strong) NSMutableDictionary *mutableIrregularPluralsBySingular;
@end

@implementation TTTStringInflector

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.mutableSingularRules = [[NSMutableArray alloc] init];
    self.mutablePluralRules = [[NSMutableArray alloc] init];
    self.mutableUncountables = [[NSMutableSet alloc] init];
    self.mutableIrregularPluralsBySingular = [[NSMutableDictionary alloc] init];

    return self;
}

+ (instancetype)defaultInflector {
    static id _defaultInflector = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _defaultInflector = [[self alloc] init];
        [_defaultInflector addPluralizationRulesForEnUSLocale];
    });

    return _defaultInflector;
}

- (NSString *)singularize:(NSString *)string {
    if ([self.mutableUncountables containsObject:string]) {
        return string;
    }

    NSArray *irregularSingulars = [self.mutableIrregularPluralsBySingular allKeysForObject:string];
    if ([irregularSingulars count] > 0) {
        return [irregularSingulars lastObject];
    }

    __block NSMutableString *mutableString = [string mutableCopy];
    [self.mutableSingularRules enumerateObjectsUsingBlock:^(id rule, NSUInteger idx, BOOL *stop) {
        *stop = !![rule evaluateString:mutableString];
    }];

    return mutableString;
}

- (NSString *)pluralize:(NSString *)string {
    if ([self.mutableUncountables containsObject:string]) {
        return string;
    }

    NSString *irregularPlural = [self.mutableIrregularPluralsBySingular objectForKey:string];
    if (irregularPlural) {
        return irregularPlural;
    }

    __block NSMutableString *mutableString = [string mutableCopy];
    [self.mutablePluralRules enumerateObjectsUsingBlock:^(id rule, NSUInteger idx, BOOL *stop) {
        *stop = !![rule evaluateString:mutableString];
    }];

    return mutableString;
}

- (void)addSingularRule:(NSString *)rule
        withReplacement:(NSString *)replacement
{
    [self.mutableUncountables removeObject:rule];

    [self.mutableSingularRules insertObject:[TTTStringInflectionRule ruleWithPattern:rule options:NSRegularExpressionAnchorsMatchLines | NSRegularExpressionCaseInsensitive | NSRegularExpressionUseUnicodeWordBoundaries replacement:replacement] atIndex:0];
}

- (void)addPluralRule:(NSString *)rule
      withReplacement:(NSString *)replacement
{
    [self.mutableUncountables removeObject:rule];
    [self.mutableUncountables removeObject:replacement];

    [self.mutablePluralRules insertObject:[TTTStringInflectionRule ruleWithPattern:rule options:NSRegularExpressionAnchorsMatchLines | NSRegularExpressionCaseInsensitive | NSRegularExpressionUseUnicodeWordBoundaries replacement:replacement] atIndex:0];
}

- (void)addIrregularWithSingular:(NSString *)singular
                          plural:(NSString *)plural
{
    [self.mutableIrregularPluralsBySingular setObject:plural forKey:singular];
    [self.mutableIrregularPluralsBySingular setObject:[plural capitalizedString] forKey:[singular capitalizedString]];
}

- (void)addUncountable:(NSString *)word {
    [self.mutableUncountables addObject:word];
}

@end

#pragma mark -

@interface TTTStringInflectionRule ()
@property (readwrite, nonatomic, strong) NSRegularExpression *regularExpression;
@property (readwrite, nonatomic, copy) NSString *replacement;
@end

@implementation TTTStringInflectionRule

+ (instancetype)ruleWithPattern:(NSString *)pattern
                        options:(NSRegularExpressionOptions)options
                    replacement:(NSString *)replacement
{
    TTTStringInflectionRule *rule = [[TTTStringInflectionRule alloc] init];
    
    NSError *error = nil;
    rule.regularExpression = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:&error];
    if (error) {
        return nil;
    }

    rule.replacement = replacement;

    return rule;
}

- (NSUInteger)evaluateString:(NSMutableString *)mutableString {
    return [self.regularExpression replaceMatchesInString:mutableString options:0 range:NSMakeRange(0, [mutableString length]) withTemplate:self.replacement];
}

@end

#pragma mark -

@implementation TTTStringInflector (Localization)

/**
 Inflection rules adapted from Active Support
 Copyright (c) 2005-2012 David Heinemeier Hansson

 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
 the following conditions:

 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
- (void)addPluralizationRulesForEnUSLocale {
    [self addPluralRule:@"$" withReplacement:@"s"];
    [self addPluralRule:@"s$" withReplacement:@"s"];
    [self addPluralRule:@"^(ax|test)is$" withReplacement:@"$1es"];
    [self addPluralRule:@"(octop|vir)us$" withReplacement:@"$1i"];
    [self addPluralRule:@"(octop|vir)i$" withReplacement:@"$1i"];
    [self addPluralRule:@"(alias|status)$" withReplacement:@"$1es"];
    [self addPluralRule:@"(bu)s$" withReplacement:@"$1ses"];
    [self addPluralRule:@"(buffal|tomat)o$" withReplacement:@"$1oes"];
    [self addPluralRule:@"([ti])um$" withReplacement:@"$1a"];
    [self addPluralRule:@"([ti])a$" withReplacement:@"$1a"];
    [self addPluralRule:@"sis$" withReplacement:@"ses"];
    [self addPluralRule:@"(?:([^f])fe|([lr])f)$" withReplacement:@"$1$2ves"];
    [self addPluralRule:@"(hive)$" withReplacement:@"$1s"];
    [self addPluralRule:@"([^aeiouy]|qu)y$" withReplacement:@"$1ies"];
    [self addPluralRule:@"(x|ch|ss|sh)$" withReplacement:@"$1es"];
    [self addPluralRule:@"(matr|vert|ind)(?:ix|ex)$" withReplacement:@"$1ices"];
    [self addPluralRule:@"^(m|l)ouse$" withReplacement:@"$1ice"];
    [self addPluralRule:@"^(m|l)ice$" withReplacement:@"$1ice"];
    [self addPluralRule:@"^(ox)$" withReplacement:@"$1en"];
    [self addPluralRule:@"^(oxen)$" withReplacement:@"$1"];
    [self addPluralRule:@"(quiz)$" withReplacement:@"$1zes"];

    [self addSingularRule:@"s$" withReplacement:@""];
    [self addSingularRule:@"(ss)$" withReplacement:@"$1"];
    [self addSingularRule:@"(n)ews$" withReplacement:@"$1ews"];
    [self addSingularRule:@"([ti])a$" withReplacement:@"$1um"];
    [self addSingularRule:@"([^f])ves$" withReplacement:@"$1fe"];
    [self addSingularRule:@"(hive)s$" withReplacement:@"$1"];
    [self addSingularRule:@"(tive)s$" withReplacement:@"$1"];
    [self addSingularRule:@"([lr])ves$" withReplacement:@"$1f"];
    [self addSingularRule:@"([^aeiouy]|qu)ies$" withReplacement:@"$1y"];
    [self addSingularRule:@"(s)eries$" withReplacement:@"$1eries"];
    [self addSingularRule:@"(m)ovies$" withReplacement:@"$1ovie"];
    [self addSingularRule:@"(x|ch|ss|sh)es$" withReplacement:@"$1"];
    [self addSingularRule:@"^(m|l)ice$" withReplacement:@"$1ouse"];
    [self addSingularRule:@"(bus)(es)?$" withReplacement:@"$1"];
    [self addSingularRule:@"(o)es$" withReplacement:@"$1"];
    [self addSingularRule:@"(shoe)s$" withReplacement:@"$1"];
    [self addSingularRule:@"(cris|test)(is|es)$" withReplacement:@"$1is"];
    [self addSingularRule:@"^(a)x[ie]s$" withReplacement:@"$1xis"];
    [self addSingularRule:@"(octop|vir)(us|i)$" withReplacement:@"$1us"];
    [self addSingularRule:@"(alias|status)(es)?$" withReplacement:@"$1"];
    [self addSingularRule:@"^(ox)en" withReplacement:@"$1"];
    [self addSingularRule:@"(vert|ind)ices$" withReplacement:@"$1ex"];
    [self addSingularRule:@"(matr)ices$" withReplacement:@"$1ix"];
    [self addSingularRule:@"(quiz)zes$" withReplacement:@"$1"];
    [self addSingularRule:@"(database)s$" withReplacement:@"$1"];

    [self addIrregularWithSingular:@"person" plural:@"people"];
    [self addIrregularWithSingular:@"man" plural:@"men"];
    [self addIrregularWithSingular:@"child" plural:@"children"];
    [self addIrregularWithSingular:@"sex" plural:@"sexes"];
    [self addIrregularWithSingular:@"move" plural:@"moves"];
    [self addIrregularWithSingular:@"cow" plural:@"cattle"];
    [self addIrregularWithSingular:@"zombie" plural:@"zombies"];

    [self addUncountable:@"equipment"];
    [self addUncountable:@"information"];
    [self addUncountable:@"rice"];
    [self addUncountable:@"money"];
    [self addUncountable:@"species"];
    [self addUncountable:@"series"];
    [self addUncountable:@"fish"];
    [self addUncountable:@"sheep"];
    [self addUncountable:@"jeans"];
}

@end
