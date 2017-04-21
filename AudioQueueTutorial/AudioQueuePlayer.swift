//
//  AudioQueuePlayer.swift
//  AudioQueueTutorial
//
//  Created by tomisacat on 19/04/2017.
//  Copyright © 2017 tomisacat. All rights reserved.
//

import AudioToolbox
import AVFoundation

func audioQueueOutputCallback(inUserData: UnsafeMutableRawPointer?, inQueue: AudioQueueRef, inBuffer: AudioQueueBufferRef) {
    if let info = inUserData?.assumingMemoryBound(to: PlayerInfo.self) {
        var bufferLength: UInt32 = info.pointee.bufferByteSize
        var numPkgs: UInt32 = kNumberPackages
        var status = AudioFileReadPacketData(info.pointee.mAudioFile!, false, &bufferLength, info.pointee.mPacketDesc, info.pointee.mCurrentPacket, &numPkgs, inBuffer.pointee.mAudioData)
        if status == noErr {
            inBuffer.pointee.mAudioDataByteSize = bufferLength
        }
        
        status = AudioQueueEnqueueBuffer(info.pointee.mQueue!, inBuffer, numPkgs, info.pointee.mPacketDesc)
        info.pointee.mCurrentPacket += Int64(numPkgs)
        
        if numPkgs == 0 {
            print("play finished")
            AudioQueueStop(info.pointee.mQueue!, false)
        }
    }
}

struct PlayerInfo {
    var mDataFormat: AudioStreamBasicDescription?
    var mQueue: AudioQueueRef?
    var mBuffers: [AudioQueueBufferRef] = []
    var mAudioFile: AudioFileID?
    var bufferByteSize: UInt32 = 0
    var mCurrentPacket: Int64 = 0
    var mPacketDesc: UnsafeMutablePointer<AudioStreamPacketDescription>?
}

fileprivate let kNumberBuffers: UInt32 = 3
fileprivate let kNumberPackages: UInt32 = 100

public class AudioQueuePlayer {
    // property
    fileprivate var audioFileUrl: URL
    fileprivate var info: PlayerInfo = PlayerInfo()
    var playing: Bool = false
    
    // life cycle
    init?(url: URL) {
        audioFileUrl = url
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return
        }
        
        var audioFile: AudioFileID?
        if AudioFileOpenURL(url as CFURL, .readPermission, 0, &audioFile) == noErr {
            info.mAudioFile = audioFile
        } else {
            return nil
        }
        
        
        var descSize: UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var dataFormat = AudioStreamBasicDescription()
        if AudioFileGetProperty(audioFile!, kAudioFilePropertyDataFormat, &descSize, &dataFormat) == noErr {
            info.mDataFormat = dataFormat
        } else {
            return nil
        }
        
        var queue: AudioQueueRef?
        if AudioQueueNewOutput(&dataFormat,
                               audioQueueOutputCallback,
                               &info,
                               CFRunLoopGetCurrent(),
                               CFRunLoopMode.commonModes.rawValue,
                               0,
                               &queue) == noErr {
            info.mQueue = queue
        } else {
            return nil
        }
        
        var maxPacketSize: UInt32 = 0
        var propertySize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
        if AudioFileGetProperty(audioFile!, kAudioFilePropertyPacketSizeUpperBound, &propertySize, &maxPacketSize) == noErr {
            info.bufferByteSize = kNumberPackages * maxPacketSize
            info.mPacketDesc = UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity: Int(kNumberPackages))
        } else {
            return nil
        }
        
        var cookieSize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
        if AudioFileGetPropertyInfo(audioFile!, kAudioFilePropertyMagicCookieData, &cookieSize, nil) == noErr {
            let magicCookie: UnsafeMutablePointer<CChar> = UnsafeMutablePointer<CChar>.allocate(capacity: Int(cookieSize))
            AudioFileGetProperty(audioFile!, kAudioFilePropertyMagicCookieData, &cookieSize, magicCookie)
            AudioQueueSetProperty(queue!, kAudioQueueProperty_MagicCookie, magicCookie, cookieSize)
            magicCookie.deallocate(capacity: Int(cookieSize))
        }
        
        info.mCurrentPacket = 0
        
        for _ in 0..<kNumberBuffers {
            var buffer: AudioQueueBufferRef?
            if AudioQueueAllocateBuffer(queue!, info.bufferByteSize, &buffer) == noErr {
                info.mBuffers.append(buffer!)
                audioQueueOutputCallback(inUserData: &info, inQueue: queue!, inBuffer: buffer!)
            } else {
                return nil
            }
        }
        
        AudioQueueSetParameter(queue!, kAudioQueueParam_Volume, 1.0)
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
        
        if let desc = info.mPacketDesc {
            desc.deallocate(capacity: Int(kNumberPackages))
            info.mPacketDesc = nil
        }
    }
}

// function
extension AudioQueuePlayer {
    func play() {
        playing = true
        AudioQueueStart(info.mQueue!, nil)
    }
    
    func pause() {
        playing = false
        AudioQueuePause(info.mQueue!)
    }
}
