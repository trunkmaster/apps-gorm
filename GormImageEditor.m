/* GormImageEditor.m
 *
 * Copyright (C) 2002 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2002
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include "GormPrivate.h"
#include "GormFunctions.h"
#include "GormPalettesManager.h"
#include <AppKit/NSImage.h>
#include "GormImage.h"

@implementation	GormImageEditor

static NSMapTable	*docMap = 0;
static int handled_mask= NSDragOperationCopy|NSDragOperationGeneric|NSDragOperationPrivate;

+ (void) initialize
{
  if (self == [GormImageEditor class])
    {
      docMap = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
				NSObjectMapValueCallBacks, 2);
    }
}

+ (GormImageEditor*) editorForDocument: (id<IBDocuments>)aDocument
{
  id	editor = NSMapGet(docMap, (void*)aDocument);

  if (editor == nil)
    {
      editor = [[self alloc] initWithObject: nil inDocument: aDocument];
      AUTORELEASE(editor);
    }
  return editor;
}

- (BOOL) acceptsTypeFromArray: (NSArray*)types
{
  return NO;
}

/*
 *	Dragging source protocol implementation
 */
- (void) draggedImage: (NSImage*)i endedAt: (NSPoint)p deposited: (BOOL)f
{
}

- (unsigned int) draggingEntered: (id<NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];
  NSArray *pbtypes = [pb types];
  unsigned int mask = [sender draggingSourceOperationMask];

  if ((mask & handled_mask) && [pbtypes containsObject: NSFilenamesPboardType])
    {
      NSArray *data;
      NSEnumerator *en;
      NSString *fileName;
      NSArray *types = [NSImage imageFileTypes];

      data = [pb propertyListForType: NSFilenamesPboardType];
      if (!data)
	{
	  data = [NSUnarchiver unarchiveObjectWithData: [pb dataForType: NSFilenamesPboardType]];
	}

      en = [data objectEnumerator];
      while((fileName = (NSString *)[en nextObject]) != nil)
	{
	  NSString *ext = [fileName pathExtension];
	  if([types containsObject: ext] == YES)
	    {
	      return NSDragOperationCopy;
	    }
	  else
	    {
	      return NSDragOperationNone;
	    }
	}

      return NSDragOperationCopy;
    }

  return NSDragOperationNone;
}

- (unsigned int) draggingUpdated: (id<NSDraggingInfo>)sender
{
  return [self draggingEntered: sender];
}

- (BOOL) performDragOperation: (id<NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];
  NSArray *types = [pb types];
  unsigned int mask = [sender draggingSourceOperationMask];

  NSDebugLLog(@"dragndrop",@"performDrag %x %@",mask,types);

   if (!(mask & handled_mask))
     return NO;

  if ([types containsObject: NSFilenamesPboardType])
    {
      NSArray *data;
      int i,c;

      data = [pb propertyListForType: NSFilenamesPboardType];
      if (!data)
	data = [NSUnarchiver unarchiveObjectWithData: [pb dataForType: NSFilenamesPboardType]];

      c=[data count];
      for (i=0;i<c;i++)
	{
	  NSString *fileName = [data objectAtIndex: i];
 	  id placeHolder =  [self placeHolderWithPath: [data objectAtIndex: i]];

	  NSLog(@"====> %@",[data objectAtIndex:i]);
	  if (placeHolder)
 	    {
 	      NSLog(@"here %@", [data objectAtIndex: i]);
   	      [self addObject: placeHolder];
	    }
	}
      return YES;
    }
  return NO;
}

- (BOOL) prepareForDragOperation: (id<NSDraggingInfo>)sender
{
  return YES;
}

- (unsigned int) draggingSourceOperationMaskForLocal: (BOOL)flag
{
  return NSDragOperationCopy;
}

- (id) placeHolderWithPath: (NSString *)string
{
  return [GormImage imageForPath: string];
}

- (void) drawSelection
{
}

- (id<IBDocuments>) document
{
  return document;
}

- (void) handleNotification: (NSNotification*)aNotification
{
  NSString *name = [aNotification name];
  if([name isEqual: GormResizeCellNotification])
    {
      NSDebugLog(@"Recieved notification");
      [self setCellSize: defaultCellSize()];
    }
}

/*
 *	Initialisation - register to receive DnD with our own types.
 */
- (id) initWithObject: (id)anObject inDocument: (id<IBDocuments>)aDocument
{
  id	old = NSMapGet(docMap, (void*)aDocument);

  if (old != nil)
    {
      RELEASE(self);
      self = RETAIN(old);
      [self addObject: anObject];
      return self;
    }

  self = [super initWithObject: anObject inDocument: aDocument];
  if (self != nil)
    {
      NSButtonCell	*proto;
      NSMutableArray    *list = [NSMutableArray array];
      NSEnumerator      *en;
      id                obj;
      GormPalettesManager *palettesManager = [(Gorm *)NSApp palettesManager];

      [self registerForDraggedTypes: [NSArray arrayWithObjects:
	NSFilenamesPboardType, nil]];

      [self setAutosizesCells: NO];
      [self setCellSize: NSMakeSize(72,72)];
      [self setIntercellSpacing: NSMakeSize(8,8)];
      [self setAutoresizingMask: NSViewMinYMargin|NSViewWidthSizable];
      [self setMode: NSRadioModeMatrix];
      /*
       * Send mouse click actions to self, so we can handle selection.
       */
      [self setAction: @selector(changeSelection:)];
      [self setDoubleAction: @selector(raiseSelection:)];
      [self setTarget: self];

      objects = [NSMutableArray new];
      proto = [NSButtonCell new];
      [proto setBordered: NO];
      [proto setAlignment: NSCenterTextAlignment];
      [proto setImagePosition: NSImageAbove];
      [proto setSelectable: NO];
      [proto setEditable: NO];
      [self setPrototype: proto];
      RELEASE(proto);
      NSMapInsert(docMap, (void*)aDocument, (void*)self);

      // do not insert it if it's nil.
      if(anObject != nil)
	{
	  [self addObject: anObject];
	}

      // add all of the system objects...
      [list addObjectsFromArray: systemImagesList()];
      [list addObjectsFromArray: [palettesManager importedImages]];
      en = [list objectEnumerator];
      while((obj = [en nextObject]) != nil)
	{
	  GormImage *image = [GormImage imageForPath: obj];
	  [image setSystemResource: YES];
	  [self addObject: image];
	}

      // set up the notification...
      [[NSNotificationCenter defaultCenter]
	addObserver: self
	selector: @selector(handleNotification:)
	name: GormResizeCellNotification
	object: nil];
    }
  return self;
}

- (void) dealloc
{
  if(closed == NO)
    [self close];

  // TODO: This is a band-aid fix until I find the actual problem. 
  // This *WILL* leak, but I don't want it crashing on people.
  
  RELEASE(objects);
  NSDebugLog(@"Released...");
}

- (void) close
{
  [super close];
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  NSMapRemove(docMap,document);
}

- (void) addObject: (id)anObject
{
  if([objects containsObject: anObject] == NO)
    {
      [super addObject: anObject];
    }
  else
    {
      NSRunAlertPanel (_(@"Problem adding image"), 
		       _(@"An image with the same name exists, remove it first."), 
		       _(@"OK"), 
		       nil, 
		       nil);      
    }
}

- (void) makeSelectionVisible: (BOOL)flag
{
  if (flag == YES && selected != nil)
    {
      unsigned	pos = [objects indexOfObjectIdenticalTo: selected];
      int	r = pos / [self numberOfColumns];
      int	c = pos % [self numberOfColumns];

      [self selectCellAtRow: r column: c];
    }
  else
    {
      [self deselectAllCells];
    }
  [self displayIfNeeded];
  [[self window] flushWindow];
}

- (void) mouseDown: (NSEvent*)theEvent
{
  int row, column;
  int newRow, newColumn;
  unsigned eventMask = NSLeftMouseUpMask | NSLeftMouseDownMask
			| NSMouseMovedMask | NSLeftMouseDraggedMask
			| NSPeriodicMask;
  NSPoint lastLocation = [theEvent locationInWindow];
  NSEvent* lastEvent = theEvent;
  NSPoint initialLocation;

  /*
   * Pathological case -- ignore mouse down
   */
  if ((_numRows == 0) || (_numCols == 0))
    {
      [super mouseDown: theEvent];
      return; 
    }

  lastLocation = [self convertPoint: lastLocation
		       fromView: nil];
  initialLocation = lastLocation;
  // If mouse down was on a selectable cell, start editing/selecting.
  if ([self getRow: &row
	    column: &column
	    forPoint: lastLocation])
    {
      if ([_cells[row][column] isEnabled])
	{
	  if ((_mode == NSRadioModeMatrix) && _selectedCell != nil)
	    {
	      [_selectedCell setState: NSOffState];
	      [self drawCellAtRow: _selectedRow column: _selectedColumn];
	      _selectedCells[_selectedRow][_selectedColumn] = NO;
	      _selectedCell = nil;
	      _selectedRow = _selectedColumn = -1;
	    }
	  [_cells[row][column] setState: NSOnState];
	  [self drawCellAtRow: row column: column];
	  [_window flushWindow];
	  _selectedCells[row][column] = YES;
	  _selectedCell = _cells[row][column];
	  _selectedRow = row;
	  _selectedColumn = column;
	}
    }
  else
    {
      return;
    }
  
  lastEvent = [NSApp nextEventMatchingMask: eventMask
		     untilDate: [NSDate distantFuture]
		     inMode: NSEventTrackingRunLoopMode
		     dequeue: YES];
  
  lastLocation = [self convertPoint: [lastEvent locationInWindow]
		       fromView: nil];


  while ([lastEvent type] != NSLeftMouseUp)
    {
      if((![self getRow: &newRow
		 column: &newColumn
		 forPoint: lastLocation])
	 ||
	 (row != newRow)
	 ||
	 (column != newColumn)
	 ||
	 ((lastLocation.x - initialLocation.x) * 
	  (lastLocation.x - initialLocation.x) +
	  (lastLocation.y - initialLocation.y) * 
	  (lastLocation.y - initialLocation.y)
	  >= 25))
	{
  	  NSPasteboard	*pb;
	  int pos;
	  pos = row * [self numberOfColumns] + column;

	  // don't allow the user to drag empty resources.
	  if(pos < [objects count])
	    {
	      pb = [NSPasteboard pasteboardWithName: NSDragPboard];
	      [pb declareTypes: [NSArray arrayWithObject: GormImagePboardType]
		  owner: self];
	      [pb setString: [(GormResource *)[objects objectAtIndex: pos] name] 
		  forType: GormImagePboardType];
	      [self dragImage: [[objects objectAtIndex: pos] image]
		    at: lastLocation
		    offset: NSZeroSize
  		    event: theEvent
		    pasteboard: pb
		    source: self
		    slideBack: YES];
	    }

	  return;
	}

      lastEvent = [NSApp nextEventMatchingMask: eventMask
			 untilDate: [NSDate distantFuture]
			 inMode: NSEventTrackingRunLoopMode
			 dequeue: YES];
      
      lastLocation = [self convertPoint: [lastEvent locationInWindow]
			   fromView: nil];

    }

  [self changeSelection: self];

}

- (void) pasteInSelection
{
}

- (void) deleteSelection
{
  if(![selected isSystemResource])
    {
      if([selected isInWrapper])
	{
	  NSFileManager *mgr = [NSFileManager defaultManager];
	  NSString *path = [selected path];
	  BOOL removed = [mgr removeFileAtPath: path
			      handler: nil];
	  if(!removed)
	    {
	      NSString *msg = [NSString stringWithFormat: @"Could not delete file %@", path];
	      NSLog(msg);
	    }
	}
      [super deleteSelection];
    }
}

- (id) raiseSelection: (id)sender
{
  id	obj = [self changeSelection: sender];
  id	e;

  e = [document editorForObject: obj create: YES];
  [e orderFront];
  [e resetObject: obj];
  return self;
}

- (void) refreshCells
{
  unsigned	count = [objects count];
  unsigned	index;
  int		cols = 0;
  int		rows;
  int		width;

  // return if the superview is not available.
  if(![self superview])
    {
      return;
    }

  width = [[self superview] bounds].size.width;
  while (width >= 72)
    {
      width -= (72 + 8);
      cols++;
    }
  if (cols == 0)
    {
      cols = 1;
    }
  rows = count / cols;
  if (rows == 0 || rows * cols != count)
    {
      rows++;
    }
  [self renewRows: rows columns: cols];

  for (index = 0; index < count; index++)
    {
      id		obj = [objects objectAtIndex: index];
      NSButtonCell	*but = [self cellAtRow: index/cols column: index%cols];
      NSString          *name = [(GormResource *)obj name];

      [but setImage: [obj imageForViewer]];
      [but setTitle: name];
      [but setShowsStateBy: NSChangeGrayCellMask];
      [but setHighlightsBy: NSChangeGrayCellMask];
    }
  while (index < rows * cols)
    {
      NSButtonCell	*but = [self cellAtRow: index/cols column: index%cols];

      [but setImage: nil];
      [but setTitle: @""];
      [but setShowsStateBy: NSNoCellMask];
      [but setHighlightsBy: NSNoCellMask];
      index++;
    }
  [self setIntercellSpacing: NSMakeSize(8,8)];
  [self sizeToCells];
  [self setNeedsDisplay: YES];
}

/*
- (void) dealloc
{
  NSLog(@"deallocing..");
  [super dealloc];
}
*/
@end


