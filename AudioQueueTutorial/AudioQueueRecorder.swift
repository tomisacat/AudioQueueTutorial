//
//  AudioQueueRecorder.swift
//  AudioQueueTutorial
//
//  Created by tomisacat on 24/04/2017.
//  Copyright © 2017 tomisacat. All rights reserved.
//

import Foundation
import AudioToolbox
import AVFoundation

fileprivate let kNumberBuffers: UInt32 = 3
fileprivate let kNumberPackages: UInt32 = 100

fileprivate struct RecorderInfo {
    var mDataFormat: AudioStreamBasicDescription = AudioStreamBasicDescription()
    var mQueue: AudioQueueRef?
    var mBuffers: [AudioQueueBufferRef] = []
    var mAudioFile: AudioFileID?
    var bufferByteSize: UInt32 = 0
    var mCurrentPacket: Int64 = 0
    var mIsRunning: Bool = false
}

fileprivate func audioQueueInputCallback(inUserData: UnsafeMutableRawPointer?,
                                         inAQ: AudioQueueRef,
                                         inBuffer: AudioQueueBufferRef,
                                         inStartTime: UnsafePointer<AudioTimeStamp>,
                                         inNumberPacketDescriptions: UInt32,
                                         inPacketDescs: UnsafePointer<AudioStreamPacketDescription>?) {
    if let info = inUserData?.assumingMemoryBound(to: RecorderInfo.self) {
        if info.pointee.mIsRunning == false {
            AudioQueueStop(info.pointee.mQueue!, true)
            AudioFileClose(info.pointee.mAudioFile!)
            return
        }
        
        var pdn = inNumberPacketDescriptions
        if inNumberPacketDescriptions == 0 && info.pointee.mDataFormat.mBytesPerPacket != 0 {  // CBR
            pdn = info.pointee.bufferByteSize / info.pointee.mDataFormat.mBytesPerPacket
        }
        
        if AudioFileWritePackets(info.pointee.mAudioFile!,
                              false,
                              info.pointee.bufferByteSize,
                              inPacketDescs,
                              info.pointee.mCurrentPacket,
                              &pdn,
                              inBuffer.pointee.mAudioData) == noErr {
            info.pointee.mCurrentPacket += Int64(pdn)
            AudioQueueEnqueueBuffer(info.pointee.mQueue!, inBuffer, 0, nil)
        }
    }
}

public class AudioQueueRecorder {
    public var outputUrl: URL
    fileprivate var info: RecorderInfo = RecorderInfo()
    public var isRecording: Bool {
        return info.mIsRunning
    }
    
    init?() {
        // setup format
        info.mDataFormat.mFormatID = kAudioFormatLinearPCM
        info.mDataFormat.mSampleRate = 444100.0
        info.mDataFormat.mChannelsPerFrame = 2
        info.mDataFormat.mBitsPerChannel = 16
        info.mDataFormat.mFramesPerPacket = 1
        info.mDataFormat.mBytesPerFrame = info.mDataFormat.mChannelsPerFrame * info.mDataFormat.mBitsPerChannel / 8
        info.mDataFormat.mBytesPerPacket = info.mDataFormat.mBytesPerFrame * info.mDataFormat.mFramesPerPacket
        info.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked | kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian
        
        // create audio input queue
        var queue: AudioQueueRef?
        if AudioQueueNewInput(&info.mDataFormat,
                              audioQueueInputCallback,
                              &info,
                              CFRunLoopGetCurrent(),
                              CFRunLoopMode.commonModes.rawValue,
                              0,
                              &queue) == noErr {
            info.mQueue = queue
        } else {
            return nil
        }
        
        // get detail format
        var dataFormatSize: UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        if AudioQueueGetProperty(queue!, kAudioQueueProperty_StreamDescription, &info.mDataFormat, &dataFormatSize) != noErr {
            return nil
        }
        
        // create file
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("audio.wav")
        outputUrl = URL(fileURLWithPath: path)
        if AudioFileCreateWithURL(outputUrl as CFURL, kAudioFileAIFFType, &info.mDataFormat, .eraseFile, &info.mAudioFile) != noErr {
            return nil
        }
        
        // allocate buffer
        info.bufferByteSize = kNumberPackages * info.mDataFormat.mBytesPerPacket
        for _ in 0..<kNumberBuffers {
            var buffer: AudioQueueBufferRef?
            if AudioQueueAllocateBuffer(queue!, info.bufferByteSize, &buffer) == noErr {
                info.mBuffers.append(buffer!)
            }
            AudioQueueEnqueueBuffer(queue!, buffer!, 0, nil)
        }
    }
    
    deinit {
        if let audio = info.mAudioFile {
            AudioFileClose(audio)
            info.mAudioFile = nil
        }
        
        if let queue = info.mQueue {
            AudioQueueDispose(queue, true)
            info.mQueue = nil
        }
    }
}

extension AudioQueueRecorder {
    public func start() {
        info.mIsRunning = true
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryRecord)
        } catch {
            return
        }
        AudioQueueStart(info.mQueue!, nil)
    }
    
    public func stop() {
        info.mIsRunning = false
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        } catch {
            return
        }
    }
}
