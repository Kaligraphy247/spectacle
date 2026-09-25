#import "SpectacleShortcutRecorder.h"

#import <Carbon/Carbon.h>

#import "SpectacleShortcut.h"
#import "SpectacleShortcutRecorder.h"
#import "SpectacleShortcutRecorderDelegate.h"
#import "SpectacleShortcutTranslations.h"
#import "SpectacleShortcutValidation.h"

static const NSTrackingAreaOptions kTrackingAreaOptions = (NSTrackingMouseEnteredAndExited
                                                           | NSTrackingActiveWhenFirstResponder
                                                           | NSTrackingEnabledDuringMouseDrag);

static const NSEventModifierFlags kCocoaModifierFlagsMask = (NSEventModifierFlagControl
                                                             | NSEventModifierFlagOption
                                                             | NSEventModifierFlagShift
                                                             | NSEventModifierFlagCommand);

static const CGFloat kFieldCornerRadius = 6.0f;

static const CGFloat kBadgeSize = 12.0f;

static const CGFloat kLabelPadding = 4.0f;

@implementation SpectacleShortcutRecorder
{
  BOOL _isRecording;
  BOOL _isMouseDown;
  BOOL _isMouseAboveBadge;
  NSTrackingArea *_badgeButtonTrackingArea;
  void *_shortcutMode;
}

- (instancetype)initWithFrame:(NSRect)frame
{
  if (self = [super initWithFrame:frame]) {
    [self _updateTrackingArea];
  }
  return self;
}

- (void)setShortcut:(SpectacleShortcut *)shortcut
{
  _shortcut = shortcut;
  [self _updateTrackingArea];
  [self setNeedsDisplay:YES];
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)resignFirstResponder
{
  [self _stopRecording];
  return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
  return YES;
}

- (void)mouseDown:(NSEvent *)event
{
  _isMouseDown = YES;
  [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event
{
  NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
  if (_badgeButtonTrackingArea && [self mouse:locationInView inRect:badgeRectInBounds(self.bounds)]) {
    if (_isRecording) {
      [self _stopRecording];
    } else {
      [self _clearShortcut];
    }
  } else if ([self mouse:locationInView inRect:self.bounds]) {
    [self _startRecording];
  } else {
    [self setNeedsDisplay:YES];
  }
  _isMouseDown = NO;
}

- (void)mouseEntered:(NSEvent *)event
{
  _isMouseAboveBadge = event.trackingArea == _badgeButtonTrackingArea;
  [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event
{
  _isMouseAboveBadge = event.trackingArea != _badgeButtonTrackingArea;
  [self setNeedsDisplay:YES];
}

- (void)keyDown:(NSEvent *)event
{
  if (![self performKeyEquivalent:event]) {
    [super keyDown:event];
  }
}

- (BOOL)performKeyEquivalent:(NSEvent *)event
{
  if (self.window.firstResponder != self) {
    return NO;
  }
  NSEventModifierFlags modifierFlags = event.modifierFlags & kCocoaModifierFlagsMask;
  if (event.keyCode == kVK_Escape && modifierFlags == 0) {
    [self _stopRecording];
    return YES;
  }
  NSInteger keyCode = event.keyCode;
  BOOL functionKey = ((keyCode == kVK_F1)  || (keyCode == kVK_F2)  || (keyCode == kVK_F3)  || (keyCode == kVK_F4)  ||
                      (keyCode == kVK_F5)  || (keyCode == kVK_F6)  || (keyCode == kVK_F7)  || (keyCode == kVK_F8)  ||
                      (keyCode == kVK_F9)  || (keyCode == kVK_F10) || (keyCode == kVK_F11) || (keyCode == kVK_F12) ||
                      (keyCode == kVK_F13) || (keyCode == kVK_F14) || (keyCode == kVK_F15) || (keyCode == kVK_F16) ||
                      (keyCode == kVK_F17) || (keyCode == kVK_F18) || (keyCode == kVK_F19) || (keyCode == kVK_F20));
  if (_isRecording && (functionKey || [SpectacleShortcut validCocoaModifiers:modifierFlags])) {
    SpectacleShortcut *shortcut = [[SpectacleShortcut alloc] initWithShortcutName:_shortcutName
                                                                  shortcutKeyCode:keyCode
                                                                shortcutModifiers:modifierFlags];
    NSError *error = nil;
    if ([_shortcutValidation isShortcutValid:shortcut error:&error]) {
      _shortcut = shortcut;
      [_delegate shortcutRecorder:self didReceiveNewShortcut:shortcut];
    } else {
      [[NSAlert alertWithError:error] runModal];
    }
    [self _stopRecording];
    return YES;
  }
  return NO;
}

- (void)flagsChanged:(NSEvent *)event
{
  if (!_isRecording) {
    return;
  }
  [self setNeedsDisplay:YES];
}

- (BOOL)clipsToBounds
{
  return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
  // Since the macOS 14 SDK the dirty rect may extend past the view, so the field is drawn from the bounds.
  NSRect rect = self.bounds;
  [self _drawBackgroundInRect:rect];
  [self _drawBadgeInRect:rect];
  [self _drawLabelInRect:rect];
}

- (void)_startRecording
{
  _isRecording = YES;
  _shortcutMode = PushSymbolicHotKeyMode(kHIHotKeyModeAllDisabled);
  [self _updateTrackingArea];
  [self setNeedsDisplay:YES];
}

- (void)_stopRecording
{
  if (!_isRecording) {
    return;
  }
  PopSymbolicHotKeyMode(_shortcutMode);
  _isRecording = NO;
  _isMouseAboveBadge = NO;
  [self _updateTrackingArea];
  [self setNeedsDisplay:YES];
}

- (void)_clearShortcut
{
  [_delegate shortcutRecorder:self didClearExistingShortcut:_shortcut];
  _shortcut = nil;
  _isMouseAboveBadge = NO;
  [self _updateTrackingArea];
  [self setNeedsDisplay:YES];
}

- (void)_updateTrackingArea
{
  if (_badgeButtonTrackingArea) {
    [self removeTrackingArea: _badgeButtonTrackingArea];
    _badgeButtonTrackingArea = nil;
  }
  if (_isRecording || _shortcut) {
    _badgeButtonTrackingArea = [[NSTrackingArea alloc] initWithRect:badgeRectInBounds(self.bounds)
                                                            options:kTrackingAreaOptions
                                                              owner:self
                                                           userInfo:nil];
    [self addTrackingArea:_badgeButtonTrackingArea];
  }
}

- (void)_drawBackgroundInRect:(NSRect)rect
{
  NSRect fieldRect = NSInsetRect(rect, 0.5f, 0.5f);
  NSBezierPath *fieldPath = [NSBezierPath bezierPathWithRoundedRect:fieldRect xRadius:kFieldCornerRadius yRadius:kFieldCornerRadius];
  NSColor *fillColor = NSColor.controlBackgroundColor;
  NSColor *strokeColor = NSColor.separatorColor;
  if (_isRecording) {
    fillColor = [NSColor.controlBackgroundColor blendedColorWithFraction:0.15f ofColor:NSColor.controlAccentColor];
    strokeColor = NSColor.controlAccentColor;
  } else if (_isMouseDown && !_isMouseAboveBadge) {
    fillColor = NSColor.unemphasizedSelectedContentBackgroundColor;
  }
  [fillColor setFill];
  [fieldPath fill];
  fieldPath.lineWidth = _isRecording ? 1.5f : 1.0f;
  [strokeColor setStroke];
  [fieldPath stroke];
}

- (void)_drawBadgeInRect:(NSRect)rect
{
  NSString *symbolName = nil;
  if ((_isRecording && !_shortcut) || (!_isRecording && _shortcut)) {
    symbolName = @"xmark.circle.fill";
  } else if (_isRecording) {
    symbolName = @"arrow.uturn.backward.circle.fill";
  } else {
    return;
  }
  NSColor *badgeColor = (_isMouseAboveBadge && _isMouseDown) ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor;
  NSImageSymbolConfiguration *configuration = [[NSImageSymbolConfiguration configurationWithPointSize:kBadgeSize
                                                                                               weight:NSFontWeightRegular]
                                               configurationByApplyingConfiguration:[NSImageSymbolConfiguration configurationWithHierarchicalColor:badgeColor]];
  NSImage *badge = [[NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil] imageWithSymbolConfiguration:configuration];
  NSRect badgeRect = badgeRectInBounds(rect);
  NSSize badgeImageSize = badge.size;
  NSRect imageRect = NSMakeRect(NSMidX(badgeRect) - badgeImageSize.width / 2.0f,
                                NSMidY(badgeRect) - badgeImageSize.height / 2.0f,
                                badgeImageSize.width,
                                badgeImageSize.height);
  [badge drawInRect:imageRect];
}

- (void)_drawLabelInRect:(NSRect)rect
{
  NSString *label = nil;
  if (_isRecording && !_isMouseAboveBadge) {
    label = NSLocalizedString(@"ShortcutRecorderLabelEnterShortcut", @"The shortcut recorder label displayed when the shorcut recorder is recording a shortcut");
  } else if (_isRecording && _isMouseAboveBadge && !_shortcut) {
    label = NSLocalizedString(@"ShortcutRecorderLabelStopRecording", @"The shortcut recorder label displayed when the shorcut recorder is recording a shortcut and the shortcut recorder does not have a previously recorded shortcut");
  } else if (_isRecording && _isMouseAboveBadge) {
    label = NSLocalizedString(@"ShortcutRecorderLabelUseExisting", "The shortcut recorder label displayed when the shorcut recorder is recording a shortcut and the shortcut recorder does have a previously recorded shortcut");
  } else if (_shortcut) {
    label = _shortcut.displayString;
  } else {
    label = NSLocalizedString(@"ShortcutRecorderLabelClickToRecord", @"The shortcut recorder label displayed when the shorcut recorder is cleared and ready to record a new shortcut");
  }
  NSEventModifierFlags modifierFlags = [NSEvent modifierFlags] & kCocoaModifierFlagsMask;
  if (_isRecording && modifierFlags) {
    label = SpectacleTranslateModifiers(modifierFlags);
  }
  [self _drawString:label inRect:rect];
}

- (void)_drawString:(NSString *)string inRect:(NSRect)rect
{
  BOOL isPrompt = _isRecording || !_shortcut;
  NSMutableParagraphStyle *paragraphStyle = NSParagraphStyle.defaultParagraphStyle.mutableCopy;
  paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
  paragraphStyle.alignment = NSTextAlignmentCenter;
  NSDictionary<NSString *, id> *attributes = @{
    NSFontAttributeName: [NSFont systemFontOfSize:NSFont.smallSystemFontSize],
    NSForegroundColorAttributeName: isPrompt ? NSColor.secondaryLabelColor : NSColor.labelColor,
    NSParagraphStyleAttributeName: paragraphStyle,
  };
  // Keep the label clear of the badge when one is shown.
  CGFloat maxX = (_isRecording || _shortcut) ? NSMinX(badgeRectInBounds(rect)) : NSMaxX(rect) - kLabelPadding;
  CGFloat labelHeight = [string sizeWithAttributes:attributes].height;
  NSRect labelRect = NSMakeRect(NSMinX(rect) + kLabelPadding,
                                NSMidY(rect) - labelHeight / 2.0f,
                                maxX - NSMinX(rect) - kLabelPadding,
                                labelHeight);
  [string drawInRect:labelRect withAttributes:attributes];
}

static NSRect badgeRectInBounds(NSRect bounds)
{
  NSRect badgeRect;
  NSSize badgeSize;
  badgeSize.width = kBadgeSize + 2.0f;
  badgeSize.height = kBadgeSize + 2.0f;
  badgeRect.origin = NSMakePoint(NSMaxX(bounds) - badgeSize.width - 3.0f, floor(NSMidY(bounds) - badgeSize.height / 2.0f));
  badgeRect.size = badgeSize;
  return badgeRect;
}

@end
