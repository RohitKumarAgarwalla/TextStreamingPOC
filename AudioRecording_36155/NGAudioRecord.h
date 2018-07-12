//
//  NGAudioRecord.h
//  AudioRecording_36155
//
//  Created by Rohit Kumar Agarwalla on 7/4/18.
//  Copyright © 2018 com.rohit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#define NUM_BUFFERS 3

typedef struct {
	AudioStreamBasicDescription			dataFormat;
	AudioQueueRef						queue;
	AudioQueueBufferRef					buffers[NUM_BUFFERS];
	AudioFileID							audioFile;
	SInt64								currentPacket;
	bool								recording;
	void*								object;
} RecordState;

typedef struct {
	AudioStreamBasicDescription			dataFormat;
	AudioQueueRef						queue;
	AudioQueueBufferRef					buffers[NUM_BUFFERS];
	AudioFileID							audioFile;
	SInt64								currentPacket;
	bool								playing;
} PlayState;

@protocol NGAudioRecordDelegate

-(void)didRecordData:(NSData *)data;

@end

@interface NGAudioRecord : NSObject
{
}

@property(nonatomic) RecordState					recordState;
@property(nonatomic) PlayState						playingState;
@property(nonatomic, weak) id<NGAudioRecordDelegate>		recordDelegate;

- (void)setupAudioFormat:(AudioStreamBasicDescription*)format;
- (void)startRecording;
- (void)stopRecording;
- (void)startPlayback;
- (void)stopPlayback;

@end
