//
//  AnimatedGifView.swift
//  AnimatedGIFViewDemo
//
//  Created by David Kasper on 9/21/14.
//

import UIKit

public class AnimatedGifView: UIView {

    public var animatedGif: AnimatedGif? {
        didSet {
            animatedGif?.size = bounds.size
            currentFrameIndex = 0
            loopCountdown = (animatedGif?.loopCount > 0 ? animatedGif?.loopCount : Int.max) ?? Int.max
            currentFrame = animatedGif?.posterImage
            layer.setNeedsDisplay()
        }
    }
    
    private var displayLink: CADisplayLink? {
        didSet {
            oldValue?.invalidate()
            displayLink?.paused = pauseAnimation
            displayLink?.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        }
    }

    public var pauseAnimation: Bool = false {
        didSet {
            displayLink?.paused = pauseAnimation
        }
    }
    
    private var accumulator: NSTimeInterval = 0
    private var currentFrame: UIImage?
    private var currentFrameIndex = 0
    private var loopCountdown = 0
    private var needsDisplayWhenImageBecomesAvailable = true
    private var shouldAnimate: Bool {
        return superview != nil && window != nil && !pauseAnimation
    }
    
    #if DEBUG
    public weak var debug_delegate: FLAnimatedImageViewDebugDelegate?
    #endif

    public override init() {
        super.init(frame: CGRectZero)
    }

    public convenience init(gif: AnimatedGif) {
        self.init()
        animatedGif = gif
        currentFrameIndex = 0
        loopCountdown = gif.loopCount > 0 ? gif.loopCount : Int.max
        currentFrame = gif.posterImage
        layer.setNeedsDisplay()
    }

    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func willMoveToWindow(newWindow: UIWindow?) {
        displayLink = newWindow != nil ? CADisplayLink(target: self, selector: "displayDidRefresh:") : nil
    }
    
    public func stopAnimating() {
        pauseAnimation = true
    }
    
    public func startAnimating() {
        pauseAnimation = false
    }

    //MARK: CADisplayLink target/action
    @objc private func displayDidRefresh(displayLink: CADisplayLink) {
        if !shouldAnimate {
            return
        }

        if let animatedGif = animatedGif {
            if let image = animatedGif.imageLazilyCachedAtIndex(currentFrameIndex) {
                currentFrame = image
                if needsDisplayWhenImageBecomesAvailable {
                    layer.setNeedsDisplay()
                    needsDisplayWhenImageBecomesAvailable = false
                }
                
                accumulator += displayLink.duration
                
                while accumulator >= animatedGif.delayTimeIntervals[currentFrameIndex] {
                    accumulator -= animatedGif.delayTimeIntervals[currentFrameIndex]
                    currentFrameIndex++
                    if currentFrameIndex >= Int(animatedGif.frameCount) {
                        loopCountdown--
                        if loopCountdown == 0 {
                            displayLink.paused = true
                            return
                        } else {
                            currentFrameIndex = 0
                        }
                    }
                    needsDisplayWhenImageBecomesAvailable = true
                }
            }
        }
    }
    
    //MARK: CALayerDelegate informal protocol
    override public func displayLayer(layer: CALayer!) {
        layer.contents =  currentFrame?.CGImage
    }
}
