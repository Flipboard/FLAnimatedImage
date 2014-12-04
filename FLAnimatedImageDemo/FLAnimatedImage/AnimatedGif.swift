//
//  AnimatedGif.swift
//  AnimatedGIFViewDemo
//
//  Created by David Kasper on 9/21/14.
//

import UIKit
import ImageIO
import CoreGraphics
import MobileCoreServices

public class AnimatedGif: NSObject, DebugAnimatedImage {
    private struct Constants {
        static let DelayTimeIntervalDefault = 0.1
        static let DelayTimeIntervalMinimum = 0.02
        static let GrowAttemptsMaximum = 2
        static let Megabyte = 1024 * 1024
        static let ResetDelay = Int64(3.0 * Double(NSEC_PER_SEC))
    }
    
    private enum AnimatedImageDataSizeCategory: Int {
        case All = 10
        case Default = 75
        case OnDemand = 250
        case Unsupported
    }
    
    private enum AnimatedImageFrameCacheSize: Int {
        case NoLimit = 0
        case LowMemory = 1
        case GrowAfterMemoryWarning = 2
        case Default = 5
    }
    
    private let colorSpaceDeviceRGBRef = CGColorSpaceCreateDeviceRGB()
    private let numberOfComponents: UInt // RGBA
    private let bitsPerComponent = UInt(CHAR_BIT)
    private let bitsPerPixel: UInt
    private let bytesPerPixel: UInt
    private let bytesPerRow: UInt
    private var alphaInfo: CGImageAlphaInfo?
    private var bitmapInfo: CGBitmapInfo?
    
    public var posterImage: UIImage!
    public var loopCount = 1
    
    // For protocol conformance
    public var delayTimes: [AnyObject] {
        return delayTimeIntervals as [AnyObject]
    }
    public var delayTimeIntervals: [NSTimeInterval]
    
    public let frameCount: UInt

    private var posterImageFrameIndex: Int!
    private let data: NSData
    private let imageSource: CGImageSourceRef
    private let imageProperties: NSDictionary
    private let imageCount: UInt = 0
    private var cachedFrames: NSMutableArray
    private let frameQueue: dispatch_queue_t = {
        let queue = dispatch_queue_create("com.wbanimatedgif.framecachingqueue", DISPATCH_QUEUE_SERIAL)
        let high = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
        dispatch_set_target_queue(queue,high)
        return queue
    }()
    private var requestedFrameIndex = 0
    private var allFrameIndexSet: NSIndexSet
    private var requestedFrameIndexes = NSMutableIndexSet()
    private var cachedFrameIndexes = NSMutableIndexSet()
    private var memoryWarningCount = 0
    private let frameCacheSizeOptimal: Int
    
    public var size = CGSizeZero
    #if DEBUG
    public weak var debug_delegate: FLAnimatedImageDebugDelegate?
    #endif
    
    // This is the definite value the frame cache needs to size itself to
    public var frameCacheSizeCurrent: Int {
        var ret = frameCacheSizeOptimal
        if frameCacheSizeMax > AnimatedImageFrameCacheSize.NoLimit.rawValue {
            ret = min(ret, frameCacheSizeMax)
        }
        if frameCacheSizeMaxInternal > AnimatedImageFrameCacheSize.NoLimit.rawValue {
            ret = min(ret, frameCacheSizeMaxInternal)
        }
        return ret
    }
    
    private var frameCacheSizeMaxInternal: Int = 0 {
        didSet {
            if frameCacheSizeMaxInternal < frameCacheSizeCurrent {
                purgeFrameCacheIfNeeded()
            }
        }
    }
    
    private var frameCacheSizeMax: Int = 0 {
        didSet {
            if frameCacheSizeMax < frameCacheSizeCurrent {
                purgeFrameCacheIfNeeded()
            }
        }
    }
    
    private var frameIndexesToCache: NSIndexSet {
        if frameCacheSizeCurrent == Int(frameCount) {
            return allFrameIndexSet
        }
        var indexesToCache = NSMutableIndexSet()
        let firstLength = min(frameCacheSizeCurrent, Int(frameCount) - requestedFrameIndex)
        let firstRange = NSMakeRange(requestedFrameIndex, firstLength)
        indexesToCache.addIndexesInRange(firstRange)
        let secondLength = frameCacheSizeCurrent - firstLength
        if secondLength > 0 {
            let secondRange = NSMakeRange(0, secondLength)
            indexesToCache.addIndexesInRange(secondRange)
        }
        indexesToCache.addIndex(posterImageFrameIndex)
        return NSIndexSet(indexSet: indexesToCache)
    }
    
    public init(gifData: NSData) {
        data = gifData
        numberOfComponents = CGColorSpaceGetNumberOfComponents(colorSpaceDeviceRGBRef) + 1
        imageSource = CGImageSourceCreateWithData(data, nil)
        
        if UTTypeConformsTo(CGImageSourceGetType(imageSource), kUTTypeGIF) == 0 {
            fatalError("Not a GIF")
        }
        
        imageProperties = CGImageSourceCopyProperties(imageSource, nil)
        var gifDictionary = imageProperties[kCGImagePropertyGIFDictionary as NSString] as? NSDictionary
        let key = kCGImagePropertyGIFLoopCount as NSString
        loopCount = gifDictionary?[kCGImagePropertyGIFLoopCount as NSString] as? Int ?? 1
        imageCount = CGImageSourceGetCount(imageSource)
        frameCount = imageCount
        allFrameIndexSet = NSIndexSet(indexesInRange: NSRange(location: 0, length: Int(frameCount)))
        delayTimeIntervals = [NSTimeInterval](count: Int(frameCount), repeatedValue: Constants.DelayTimeIntervalMinimum)
        cachedFrames = NSMutableArray(capacity: Int(frameCount))
        for i in 0 ..< Int(frameCount) {
            cachedFrames[i] = NSNull()
        }
        for index in 0 ..< imageCount {
            if posterImage == nil {
                if let frameImageRef = CGImageSourceCreateImageAtIndex(imageSource, index, nil) {
                    if let frameImage = UIImage(CGImage: frameImageRef) {
                        posterImage = frameImage
                        size = posterImage.size
                        posterImageFrameIndex = Int(index)
                        cachedFrames[Int(index)] = frameImage
                        cachedFrameIndexes.addIndex(Int(index))
                    }
                }
            }
                
            let frameProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as NSDictionary
            var frameGifProperties = frameProperties[kCGImagePropertyGIFDictionary as NSString] as NSDictionary?
            
            var delayTime: NSTimeInterval
            if let unclampedDelay = frameGifProperties![kCGImagePropertyGIFUnclampedDelayTime as NSString] as? NSTimeInterval {
                delayTime = unclampedDelay
            } else if let delay = frameGifProperties![kCGImagePropertyGIFDelayTime as NSString] as? NSTimeInterval {
                delayTime = delay
            } else {
                delayTime = Constants.DelayTimeIntervalMinimum //minimum
            }
            if delayTime < Constants.DelayTimeIntervalMinimum {
                delayTime = Constants.DelayTimeIntervalDefault
            }
            
            delayTimeIntervals[Int(index)] = delayTime
        }
        
        bitsPerPixel = (bitsPerComponent * numberOfComponents)
        bytesPerPixel = (bitsPerPixel / UInt(BYTE_SIZE))
        bytesPerRow = (bytesPerPixel * UInt(size.width))
        
        let animatedImageDataSize = Int(CGImageGetBytesPerRow(posterImage.CGImage)) * Int(posterImage.size.height) * Int(frameCount) / Constants.Megabyte
        if animatedImageDataSize <= AnimatedImageDataSizeCategory.All.rawValue {
            frameCacheSizeOptimal = Int(frameCount)
        } else if animatedImageDataSize <= AnimatedImageDataSizeCategory.Default.rawValue {
            frameCacheSizeOptimal = AnimatedImageFrameCacheSize.Default.rawValue
        } else {
            frameCacheSizeOptimal = AnimatedImageFrameCacheSize.LowMemory.rawValue
        }
        frameCacheSizeOptimal = min(Int(frameCount), frameCacheSizeOptimal)
        
        super.init()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didReceiveMemoryWarning:", name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
    }
    
    func didReceiveMemoryWarning(notification: NSNotification) {
        memoryWarningCount++
        frameCacheSizeMaxInternal = AnimatedImageFrameCacheSize.LowMemory.rawValue
        if memoryWarningCount < Constants.GrowAttemptsMaximum {
            growFrameCacheSizeAfterMemoryWarning(AnimatedImageFrameCacheSize.GrowAfterMemoryWarning.rawValue)
        }
    }
    
    private func growFrameCacheSizeAfterMemoryWarning(frameCacheSize: Int) {
        frameCacheSizeMaxInternal = frameCacheSize
        
        weak var weakSelf = self
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Constants.ResetDelay), dispatch_get_main_queue()) {
            weakSelf?.resetFrameCacheSizeMaxInternal()
            return
        }
    }
    
    private func resetFrameCacheSizeMaxInternal() {
        frameCacheSizeMaxInternal = AnimatedImageFrameCacheSize.NoLimit.rawValue
    }
    
    public func imageLazilyCachedAtIndex(index: Int) -> UIImage? {
        if index >= Int(frameCount) {
            return nil
        }
        requestedFrameIndex = index
        
        #if DEBUG
        self.debug_delegate?.debug_animatedImage?(self, didRequestCachedFrame: UInt(index))
        #endif
        
        if cachedFrameIndexes.count < Int(frameCount) {
            var indexesToCache = NSMutableIndexSet(indexSet: frameIndexesToCache)
            indexesToCache.removeIndexes(cachedFrameIndexes)
            indexesToCache.removeIndexes(requestedFrameIndexes)
            indexesToCache.removeIndex(posterImageFrameIndex)
            if indexesToCache.count > 0 {
                addFrameIndexesToCache(NSIndexSet(indexSet: indexesToCache))
            }
        }
        purgeFrameCacheIfNeeded()
        return cachedFrames[index] as? UIImage
    }
    
    private func addFrameIndexesToCache(frameIndexesToAddToCache: NSIndexSet) {
        weak var weakSelf = self
        requestedFrameIndexes.addIndexes(frameIndexesToAddToCache)
        // Start caching at the requested frame
        for range in [ NSRange(location: requestedFrameIndex, length: Int(frameCount) - requestedFrameIndex), NSRange(location: 0, length: requestedFrameIndex) ] {
            frameIndexesToAddToCache.enumerateIndexesInRange(range, options: nil) { index, _ in
                dispatch_async(self.frameQueue) {
                    if let imageSource = weakSelf?.imageSource {
                        if weakSelf?.requestedFrameIndexes.containsIndex(index) ?? false {
                            if let image = weakSelf?.predrawnImageAtIndex(UInt(index)) {
                                dispatch_async(dispatch_get_main_queue()) {
                                    weakSelf?.cachedFrames[index] = image
                                    weakSelf?.cachedFrameIndexes.addIndex(index)
                                    weakSelf?.requestedFrameIndexes.removeIndex(index)
                                    
                                    #if DEBUG
                                    weakSelf?.debug_delegate?.debug_animatedImage?(weakSelf!, didUpdateCachedFrames: weakSelf?.cachedFrameIndexes)
                                    #endif
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func predrawnImageAtIndex(index: UInt) -> UIImage? {
        var imageRef = CGImageSourceCreateImageAtIndex(imageSource, index, nil)
        if let image = UIImage(CGImage: imageRef) {
            return predrawnImageFromImage(image)
        }
        return nil
    }
    
    func precalculateImageInfo(imageToPredraw: UIImage) {
        if alphaInfo == nil {
            alphaInfo = CGImageGetAlphaInfo(imageToPredraw.CGImage)
            if alphaInfo == .None || alphaInfo == .Only {
                alphaInfo = .NoneSkipFirst
            } else if alphaInfo == .First {
                alphaInfo = .PremultipliedFirst
            } else if alphaInfo == .Last {
                alphaInfo = .PremultipliedLast
            }
            bitmapInfo = CGBitmapInfo(CGBitmapInfo.ByteOrderDefault.rawValue | alphaInfo!.rawValue)
        }
    }
    
    func predrawnImageFromImage(imageToPredraw: UIImage) -> UIImage? {
        precalculateImageInfo(imageToPredraw)
        let bitmapContextRef = CGBitmapContextCreate(nil, UInt(imageToPredraw.size.width), UInt(imageToPredraw.size.height), bitsPerComponent, bytesPerRow, colorSpaceDeviceRGBRef, bitmapInfo!)
        
        CGContextDrawImage(bitmapContextRef, CGRect(origin: CGPointZero, size: imageToPredraw.size), imageToPredraw.CGImage)
        let predrawnImageRef = CGBitmapContextCreateImage(bitmapContextRef)
        return UIImage(CGImage: predrawnImageRef, scale: imageToPredraw.scale, orientation: imageToPredraw.imageOrientation)
    }
    
    private func purgeFrameCacheIfNeeded() {
        if cachedFrameIndexes.count > frameCacheSizeCurrent {
            var indexesToPurge = NSMutableIndexSet(indexSet: cachedFrameIndexes)
            indexesToPurge.removeIndexes(frameIndexesToCache)
            indexesToPurge.enumerateRangesUsingBlock { nsrange, _ in
                if let range = nsrange.toRange() {
                    for index in range {
                        self.cachedFrameIndexes.removeIndex(index)
                        self.cachedFrames[index] = NSNull()
                        
                        #if DEBUG
                        self.debug_delegate?.debug_animatedImage?(self, didUpdateCachedFrames: self.cachedFrameIndexes)
                        #endif
                    }
                }
            }
        }
    }
}
