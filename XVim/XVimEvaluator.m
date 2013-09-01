//
//  XVimEvaluator.m
//  XVim
//
//  Created by Shuichiro Suzuki on 2/3/12.  
//  Copyright 2012 JugglerShu.Net. All rights reserved.  
//

#import "XVim.h"
#import "XVimOptions.h"
#import "XVimEvaluator.h"
#import "XVimMotionEvaluator.h"
#import "XVimKeyStroke.h"
#import "Logger.h"
#import "XVimWindow.h"
#import "XVimKeymapProvider.h"
#import "XVimNormalEvaluator.h"
#import "XVimVisualEvaluator.h"
#import "XVim.h"
#import "NSTextView+VimOperation.h"
#import "XVimSearch.h"
#import "XVimCommandLineEvaluator.h"

static XVimEvaluator* _invalidEvaluator = nil;
static XVimEvaluator* _noOperationEvaluator = nil;

@implementation XVimEvaluator

+ (XVimEvaluator*)invalidEvaluator{
   	if(_invalidEvaluator){
        return _invalidEvaluator;
    }
    
	@synchronized([XVimEvaluator class]){
		if(!_invalidEvaluator) {
			_invalidEvaluator = [[XVimEvaluator alloc] init];
		}
	}
    return _invalidEvaluator;
}

+ (XVimEvaluator*)noOperationEvaluator{
   	if(_noOperationEvaluator){
        return _noOperationEvaluator;
    }
    
	@synchronized([XVimEvaluator class]){
		if(!_noOperationEvaluator) {
			_noOperationEvaluator = [[XVimEvaluator alloc] init];
		}
	}
    return _noOperationEvaluator;
}

- (id)init {
    self = [super init];
	return self;
}

- (id)initWithWindow:(XVimWindow*)window{
    NSAssert( nil != window, @"window must not be nil");
    if(self = [super init]){
        self.window = window;
        self.parent = nil;
        self.argumentString = [[[NSMutableString alloc] init] autorelease];
        self.numericArg = 1;
        self.numericMode = NO;
        self.yankRegister = nil;
        self.onChildCompleteHandler = @selector(onChildComplete:);
    }
    return self;
}

- (void)dealloc{
    self.window = nil;
    self.parent = nil;
    self.argumentString = nil;
    self.yankRegister = nil;
    [super dealloc];
}

- (NSTextView*)sourceView{
    return self.window.sourceView;
}

- (XVimEvaluator*)eval:(XVimKeyStroke*)keyStroke{
    // This is default implementation of evaluator.
    // Only keyDown events are supposed to be passed here.	
    // Invokes each key event handler
    // <C-k> invokes "C_k:" selector
	
	SEL handler = [keyStroke selectorForInstance:self];
	if (handler) {
		TRACE_LOG(@"Calling SELECTOR %@", NSStringFromSelector(handler));
        return [self performSelector:handler];
	}
    else{
        TRACE_LOG(@"SELECTOR %@ not found", NSStringFromSelector(handler));
        return [self defaultNextEvaluator];
    }
    
}

- (XVimEvaluator*)onChildComplete:(XVimEvaluator*)childEvaluator{
    return nil;
}
   
- (void)becameHandler{
    self.sourceView.xvimDelegate = self;
}

- (void)didEndHandler{
    self.sourceView.xvimDelegate = nil;
}

- (XVimKeymap*)selectKeymapWithProvider:(id<XVimKeymapProvider>)keymapProvider {
	return [keymapProvider keymapForMode:XVIM_MODE_NORMAL];
}

- (XVimEvaluator*)defaultNextEvaluator{
    return [XVimEvaluator invalidEvaluator];
}

- (XVimEvaluator*)handleMouseEvent:(NSEvent*)event{
	if( self.sourceView.selectionMode == XVIM_VISUAL_NONE){
        return [[[XVimNormalEvaluator alloc] init] autorelease];
    }else{
        //return [[[XVimVisualEvaluator alloc] initWithWindow:self.window mode:XVIM_VISUAL_CHARACTER withRange:NSMakeRange(0,0)] autorelease];
        return [[[XVimNormalEvaluator alloc] init] autorelease];
    }
}

- (void)drawRect:(NSRect)rect{
}

- (BOOL)shouldDrawInsertionPoint{
	return YES;
}

- (float)insertionPointHeightRatio{
    return 1.0;
}

- (float)insertionPointWidthRatio{
    return 1.0;
}

- (float)insertionPointAlphaRatio{
    return 0.5;
}

- (NSString*)modeString {
	return @"";
}

- (XVIM_MODE)mode{
    return XVIM_MODE_NORMAL;
}

- (BOOL)isRelatedTo:(XVimEvaluator*)other {
	return other == self;
}

- (XVimEvaluator*)D_d{
    // This is for debugging purpose.
    // Write any debugging process to confirme some behaviour.
    return nil;
}

- (XVimEvaluator*)ESC{
    return [XVimEvaluator invalidEvaluator];
}

// Normally argumentString, but can be overridden
- (NSString*)argumentDisplayString {
    if( nil == self.parent ){
        return _argumentString;
    }else{
        return [[self.parent argumentDisplayString] stringByAppendingString:_argumentString];
    }
}

// Returns the context yank register if any
- (NSString*)yankRegister {
    // Never use self.yankRegister here. It causes INFINITE LOOP
    if( nil != _yankRegister ){
        return [[_yankRegister retain] autorelease];
    }
    if( nil == self.parent ){
        return _yankRegister;
    }else{
        return [self.parent yankRegister];
    }
}

- (void)resetNumericArg{
    _numericArg = 1;
    if( self.parent != nil ){
        [self.parent resetNumericArg];
    }
}

// Returns the context numeric arguments multiplied together
- (NSUInteger)numericArg {
    // FIXME: This may lead integer overflow.
    // Just cut it to INT_MAX is fine for here I think.
    if( nil == self.parent ){
        return _numericArg;
    }else{
        return [self.parent numericArg] * _numericArg;
    }
}

- (BOOL)numericMode{
    if( nil == self.parent ){
        return _numericMode;
    }else{
        return [self.parent numericMode];
    }
}

- (void)textView:(NSTextView*)view didYank:(NSString*)yankedText withType:(TEXT_TYPE)type{
    [[[XVim instance] registerManager] yank:yankedText withType:type onRegister:self.yankRegister];
    return;
}

- (void)textView:(NSTextView*)view didDelete:(NSString*)deletedText withType:(TEXT_TYPE)type{
    [[[XVim instance] registerManager] delete:deletedText withType:type onRegister:self.yankRegister];
    return;
}

- (XVimCommandLineEvaluator*)searchEvaluatorForward:(BOOL)forward{
	return [[[XVimCommandLineEvaluator alloc] initWithWindow:self.window
                                                 firstLetter:forward?@"/":@"?"
                                                     history:[[XVim instance] searchHistory]
                                                  completion:^ XVimEvaluator* (NSString *command, id* result)
             {
                 if( command.length == 0 ){
                     return nil;
                 }
                 
                 MOTION_OPTION opt = MOTION_OPTION_NONE;
                 if( [XVim instance].options.wrapscan ){
                     opt |= SEARCH_WRAP;
                 }
                 if( [XVim instance].options.ignorecase ){
                     opt |= SEARCH_CASEINSENSITIVE;
                 }
                 
                 [XVim instance].searcher.lastSearchString = [command substringFromIndex:1];
                 
                 if( [XVim instance].options.vimregex ){
                     // TODO:
                     // Convert Vim regex to ICU regex
                 }
                 XVimMotion* m = nil;
                 if( [command characterAtIndex:0] == '/' ){
                     XVim.instance.searcher.lastSearchBackword = NO;
                     m = XVIM_MAKE_MOTION(MOTION_SEARCH_FORWARD, CHARACTERWISE_EXCLUSIVE, opt, self.numericArg);
                 }else{
                     XVim.instance.searcher.lastSearchBackword = YES;
                     m = XVIM_MAKE_MOTION(MOTION_SEARCH_BACKWARD, CHARACTERWISE_EXCLUSIVE, opt, self.numericArg);
                 }
                 m.regex = [XVim instance].searcher.lastSearchString;
                 *result = m;
                 return nil;
             }
             onKeyPress:^void(NSString *command)
             {
                 if( command.length == 0 ){
                     return;
                 }
                 
                 MOTION_OPTION opt = MOTION_OPTION_NONE;
                 if( [XVim instance].options.wrapscan ){
                     opt |= SEARCH_WRAP;
                 }
                 if( [XVim instance].options.ignorecase ){
                     opt |= SEARCH_CASEINSENSITIVE;
                 }
                 
                 NSString* str = [command substringFromIndex:1];
                 if( [XVim instance].options.vimregex ){
                     // TODO:
                     // Convert Vim regex to ICU regex
                 }
                 if( [command characterAtIndex:0] == '/' ){
                     [self.sourceView xvim_highlightNextSearchCandidateForward:str count:self.numericArg option:opt];
                 }else{
                     [self.sourceView xvim_highlightNextSearchCandidateBackward:str count:self.numericArg option:opt];
                 }
             }] autorelease];
}

@end


