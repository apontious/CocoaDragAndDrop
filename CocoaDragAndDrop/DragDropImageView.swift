//
//  DragDropImageView.swift
//  CocoaDragAndDrop
//
//  Created by Andrew Pontious on 7/2/17.
//  Copyright (c) 2017 Andrew Pontious.
//  Some right reserved: http://opensource.org/licenses/mit-license.php
//

import Cocoa

#if swift(>=4.0)
	fileprivate let kPrivateDragUTI = NSPasteboard.PasteboardType("com.yourcompany.cocoadraganddrop")
#else
	fileprivate let kPrivateDragUTI = "com.yourcompany.cocoadraganddrop"
#endif

class DragDropImageView : NSImageView, NSDraggingSource, NSWindowDelegate, NSPasteboardItemDataProvider
{
	// Highlight the drop zone.
	fileprivate var highlight: Bool = false
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		// Register for all the image types we can display.
		#if swift(>=4.0)
			registerForDraggedTypes(NSImage.imagePasteboardTypes())
		#else
			register(forDraggedTypes: NSImage.imagePasteboardTypes())
		#endif
	}
	
	// MARK: - NSResponder
	
	override func mouseDown(with event: NSEvent)
	{
		/*------------------------------------------------------
		catch mouse down events in order to start drag
		--------------------------------------------------------*/
		
		/* Dragging operation occur within the context of a special pasteboard (NSDragPboard).
		* All items written or read from a pasteboard must conform to NSPasteboardWriting or
		* NSPasteboardReading respectively.  NSPasteboardItem implements both these protocols
		* and is as a container for any object that can be serialized to NSData. */
		
		let pbItem = NSPasteboardItem()
		/* Our pasteboard item will support public.tiff, public.pdf, and our custom UTI (see comment in -draggingEntered)
		* representations of our data (the image).  Rather than compute both of these representations now, promise that
		* we will provide either of these representations when asked.  When a receiver wants our data in one of the above
		* representations, we'll get a call to  the NSPasteboardItemDataProvider protocol method –pasteboard:item:provideDataForType:. */
		#if swift(>=4.0)
			let types = [NSPasteboard.PasteboardType.tiff, NSPasteboard.PasteboardType.pdf, kPrivateDragUTI]
		#else
			let types = [NSPasteboardTypeTIFF, NSPasteboardTypePDF, kPrivateDragUTI]
		#endif
		pbItem.setDataProvider(self, forTypes: types)
		
		// Create a new NSDraggingItem with our pasteboard item.
		let dragItem = NSDraggingItem(pasteboardWriter: pbItem)
		
		/* The coordinates of the dragging frame are relative to our view.  Setting them to our view's bounds will cause the drag image
		* to be the same size as our view.  Alternatively, you can set the draggingFrame to an NSRect that is the size of the image in
		* the view but this can cause the dragged image to not line up with the mouse if the actual image is smaller than the size of the
		* our view. */
		let draggingRect = bounds;
		
		/* While our dragging item is represented by an image, this image can be made up of multiple images which
		* are automatically composited together in painting order.  However, since we are only dragging a single
		* item composed of a single image, we can use the convince method below. For a more complex example
		* please see the MultiPhotoFrame sample. */
		dragItem.setDraggingFrame(draggingRect, contents: image)
		
		// Create a dragging session with our drag item and ourself as the source.
		let draggingSession = beginDraggingSession(with: [dragItem], event: event, source: self)
		// Causes the dragging item to slide back to the source if the drag fails.
		draggingSession.animatesToStartingPositionsOnCancelOrFail = true
		
		draggingSession.draggingFormation = .none
	}
	
	// MARK: - NSView
	
	override func draw(_ dirtyRect: NSRect)
	{
		/*------------------------------------------------------
		draw method is overridden to do drop highlighing
		--------------------------------------------------------*/
		// Do the usual draw operation to display the image.
		super.draw(dirtyRect)
		
		if highlight {
			// Highlight by overlaying a gray border.
			NSColor.gray.set()
			#if swift(>=4.0)
				NSBezierPath.defaultLineWidth = 5
			#else
				NSBezierPath.setDefaultLineWidth(5)
			#endif
			NSBezierPath.stroke(dirtyRect)
		}
	}
	
	override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
		/*------------------------------------------------------
		accept activation click as click in window
		--------------------------------------------------------*/
		// So source doesn't have to be the active window.
		return true
	}
	
	// MARK: - NSDraggingSource
	
	func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation
	{
		/*------------------------------------------------------
		NSDraggingSource protocol method.  Returns the types of operations allowed in a certain context.
		--------------------------------------------------------*/
		switch context {
		case .outsideApplication:
			return .copy
			
		// By using this fall through pattern, we will remain compatible if the contexts get more precise in the future.
		case .withinApplication:
			return.copy
		}
	}
	
	// MARK: - NSDraggingDestination
	
	override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation
	{
		/*------------------------------------------------------
		method called whenever a drag enters our drop zone
		--------------------------------------------------------*/
		
		// Check if the pasteboard contains image data and source/user wants it copied.
		if NSImage.canInit(with: sender.draggingPasteboard()) &&
			sender.draggingSourceOperationMask().contains(.copy) {
			// Highlight our drop zone.
			highlight = true
			
			needsDisplay = true
			
			/* When an image from one window is dragged over another, we want to resize the dragging item to
			* preview the size of the image as it would appear if the user dropped it in. */
			sender.enumerateDraggingItems(options: .concurrent, for: self, classes: [NSPasteboardItem.self], searchOptions: [:]) { (draggingItem, idx, stop) in
				/* Only resize a dragging item if it originated from one of our windows.  To do this,
				* we declare a custom UTI that will only be assigned to dragging items we created.  Here
				* we check if the dragging item can represent our custom UTI.  If it can't we stop. */
				if  draggingItem.item as? NSPasteboardItem == nil || !(draggingItem.item as! NSPasteboardItem).types.contains(kPrivateDragUTI) {
					stop.pointee = true
				} else {
					/* In order for the dragging item to actually resize, we have to reset its contents.
					* The frame is going to be the destination view's bounds.  (Coordinates are local
					* to the destination view here).
					* For the contents, we'll grab the old contents and use those again.  If you wanted
					* to perform other modifications in addition to the resize you could do that here. */
					draggingItem.setDraggingFrame(self.bounds, contents: draggingItem.imageComponents?.first?.contents)
				}
			}
			
			// Accept data as a copy operation.
			return .copy
		}
		
		return []
	}
	
	override func draggingExited(_ sender: NSDraggingInfo?)
	{
		/*------------------------------------------------------
		method called whenever a drag exits our drop zone
		--------------------------------------------------------*/
		// Remove highlight of the drop zone.
		highlight = false
		
		needsDisplay = true
	}
	
	override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
		/*------------------------------------------------------
		method to determine if we can accept the drop
		--------------------------------------------------------*/
		// Finished with the drag so remove any highlighting.
		highlight = false
		
		needsDisplay = true
		
		// Check to see if we can accept the data.
		return NSImage.canInit(with: sender.draggingPasteboard())
	}
	
	override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
		/*------------------------------------------------------
		method that should handle the drop data
		--------------------------------------------------------*/
		if sender.draggingSource() as? DragDropImageView == self {
			// Set the image using the best representation we can get from the pasteboard.
			if NSImage.canInit(with: sender.draggingPasteboard()) {
				image = NSImage(pasteboard: sender.draggingPasteboard())
			}
			
			// If the drag comes from a file, set the window title to the filename.
			let fileURL = NSURL(from: sender.draggingPasteboard())
			if let windowTitle = fileURL?.absoluteString {
				window?.title = windowTitle
			} else {
				window?.title = "(no name)"
			}
		}
		
		return true
	}
	
	// MARK: - NSWindowDelegate
	
	func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect
	{
		if let image = image {
			/*------------------------------------------------------
			delegate operation to set the standard window frame
			--------------------------------------------------------*/
			// Get window frame size.
			var contentRect = window.frame
			
			// Set it to the image frame size.
			contentRect.size = image.size
			
			return NSWindow.frameRect(forContentRect: contentRect, styleMask: window.styleMask)
		} else {
			return newFrame
		}
	}
	
	// MARK: - NSPasteboardItemDataProvider
	
	#if swift(>=4.0)
	func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType)
{
	/*------------------------------------------------------
	method called by pasteboard to support promised
	drag types.
	--------------------------------------------------------*/
	// Sender has accepted the drag and now we need to send the data for the type we promised.
	if type == NSPasteboard.PasteboardType.tiff {
	// Set data for TIFF type on the pasteboard as requested.
	pasteboard?.setData(image?.tiffRepresentation, forType: NSPasteboard.PasteboardType.tiff)
	} else if type == NSPasteboard.PasteboardType.pdf {
	// Set data for PDF type on the pasteboard as requested.
	pasteboard?.setData(dataWithPDF(inside: bounds), forType: NSPasteboard.PasteboardType.pdf)
	}
	}
	#else
	func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: String)
	{
		/*------------------------------------------------------
		method called by pasteboard to support promised
		drag types.
		--------------------------------------------------------*/
		// Sender has accepted the drag and now we need to send the data for the type we promised.
		if type == NSPasteboardTypeTIFF {
			// Set data for TIFF type on the pasteboard as requested.
			pasteboard?.setData(image?.tiffRepresentation, forType: NSPasteboardTypeTIFF)
		} else if type == NSPasteboardTypePDF {
			// Set data for PDF type on the pasteboard as requested.
			pasteboard?.setData(dataWithPDF(inside: bounds), forType: NSPasteboardTypePDF)
		}
	}
	#endif
}

