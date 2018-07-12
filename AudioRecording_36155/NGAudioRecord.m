//
//  NGAudioRecord.m
//  AudioRecording_36155
//
//  Created by Rohit Kumar Agarwalla on 7/4/18.
//  Copyright © 2018 com.rohit. All rights reserved.
//

#import "NGAudioRecord.h"
#define AUDIO_DATA_TYPE_FORMAT SInt16
int ima_index_table[16] = {
	-1, -1, -1, -1, 2, 4, 6, 8,
	-1, -1, -1, -1, 2, 4, 6, 8
};
int ima_step_table[89] = {
	7, 8, 9, 10, 11, 12, 13, 14, 16, 17,
	19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
	50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
	130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
	337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
	876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
	2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
	5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
	15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767
};

Byte volumeForPacket(const UInt8* packet, int packetSize) {
	
	float power = 0;
	
	int header = (packet[0] << 8 | packet[1]); // first 16 bits are header data
	
	SInt8 step_index = header & 0x007F; // Bottom 7 bits initialize the step_index
	
	if (step_index < 0)
		step_index = 0;
	if (step_index > 88)
		step_index = 88;
	
	int predictor = header & 0xFFFFFF80; // Upper 9 bits initialize the predictor
	if (predictor > 32767) predictor = predictor-65536;
	
	int step = ima_index_table[step_index]; // Initialize the step
	
	
	for (int x = 2; x < packetSize; x++) {
		UInt8 data = packet[x];
		
		for (int x = 0; x < 2; x++) {
			UInt8 nibble = 0;
			
			if (x == 0)
				nibble = data & 0x0F;
			else
				nibble = data >> 4;
			
			step_index += ima_index_table[nibble];
			if (step_index < 0) step_index = 0;
			if (step_index > 88) step_index = 88;
			
			int diff = step >> 3;
			if (nibble & 4) diff += step;
			if (nibble & 2) diff += (step >> 1);
			if (nibble & 1) diff += (step >> 2);
			if (nibble & 8) predictor -= diff;
			else predictor += diff;
			
			if (predictor < -32768) predictor = -32768;
			if (predictor > 32767) predictor = 32767;
			
			step = ima_step_table[step_index];
			
			power = MAX(power, (float)abs(predictor) / 32767.0);
		}
	}
	
	float waveRange = 30.f; // Increase to make the wave appear more sensitive
	
	float db = MIN(1, MAX(0, (20.0 * log10f(power) + waveRange) / waveRange));
	
	Byte volume = db * 255;
	return volume;
}

void AudioInputCallback(void * inUserData,  // Custom audio metadata
						AudioQueueRef inAQ,
						AudioQueueBufferRef inBuffer,
						const AudioTimeStamp * inStartTime,
						UInt32 inNumberPacketDescriptions,
						const AudioStreamPacketDescription * inPacketDescs);

void AudioOutputCallback(void * inUserData,
						 AudioQueueRef outAQ,
						 AudioQueueBufferRef outBuffer);

@implementation NGAudioRecord {
	CFURLRef			fileURL;
}

void AudioInputCallback(void * inUserData,
						AudioQueueRef inAQ,
						AudioQueueBufferRef inBuffer,
						const AudioTimeStamp * inStartTime,
						UInt32 inNumberPacketDescriptions,
						const AudioStreamPacketDescription * inPacketDescs)
{
	RecordState * recordState = (RecordState*)inUserData;
	NGAudioRecord *temp = (__bridge NGAudioRecord *)recordState->object;
	
	if (!recordState->recording)
	{
		printf("Not recording, returning\n");
	}
	
	// if (inNumberPacketDescriptions == 0 && recordState->dataFormat.mBytesPerPacket != 0)
	// {
	//     inNumberPacketDescriptions = inBuffer->mAudioDataByteSize / recordState->dataFormat.mBytesPerPacket;
	// }
	
//	printf("Writing buffer %lld\n", recordState->currentPacket);
	OSStatus status = AudioFileWritePackets(recordState->audioFile,
											false,
											inBuffer->mAudioDataByteSize,
											inPacketDescs,
											recordState->currentPacket,
											&inNumberPacketDescriptions,
											inBuffer->mAudioData);
	
	printf("Audio Status %d\n", (int)status);
	
	if (status == 0)
	{
		recordState->currentPacket += inNumberPacketDescriptions;
	}
	
	OSStatus status1 = AudioQueueEnqueueBuffer(recordState->queue, inBuffer, 0, NULL);
	printf("Audio enqueue status1 %d\n", (int)status1);

	NSMutableArray *vudata = [[NSMutableArray alloc] initWithCapacity:inNumberPacketDescriptions];
	int packetSize = recordState->dataFormat.mBytesPerPacket;
	
	for (int p = 0; p < inNumberPacketDescriptions; p++) {
		Byte volume = volumeForPacket((UInt8*)inBuffer->mAudioData + p * packetSize, packetSize);
		// Store our peak power in 0-255
		[vudata addObject:@(volume)];
	}

	// Converting the array into NSData to be passed to nVoq
	NSError *dataConversionError = nil;
	NSData *data = [NSPropertyListSerialization dataWithPropertyList:vudata format:NSPropertyListBinaryFormat_v1_0 options:0 error:&dataConversionError];
	
	if (dataConversionError == nil) {
		[temp.recordDelegate didRecordData:data];
	} else {
		NSLog(@"Conversion error %@", dataConversionError);
	}
//	NSData *tempData = [NSData dataWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
//	[temp feedSamplesToEngine:inBuffer->mAudioDataByteSize audioData:inBuffer->mAudioData];
	
}

// Fills an empty buffer with data and sends it to the speaker
void AudioOutputCallback(void * inUserData,
						 AudioQueueRef outAQ,
						 AudioQueueBufferRef outBuffer)
{
	PlayState* playState = (PlayState*)inUserData;
	if(!playState->playing)
	{
		printf("Not playing, returning\n");
		return;
	}
	
	printf("Queuing buffer %lld for playback\n", playState->currentPacket);

	AudioStreamPacketDescription* packetDescs = NULL;
	
	UInt32 bytesRead;
	UInt32 numPackets = 8000;
	OSStatus status;
	status = AudioFileReadPacketData(playState->audioFile,
									 false,
									 &bytesRead,
									 packetDescs,
									 playState->currentPacket,
									 &numPackets,
									 outBuffer->mAudioData);
	printf("No of packets are %u", (unsigned int)numPackets);
	if (numPackets)
	{
		outBuffer->mAudioDataByteSize = bytesRead;
		status = AudioQueueEnqueueBuffer(playState->queue,
										 outBuffer,
										 0,
										 packetDescs);
		
		playState->currentPacket += numPackets;
	}
	else
	{
		if (playState->playing)
		{
			AudioQueueStop(playState->queue, false);
			AudioFileClose(playState->audioFile);
			playState->playing = false;
		}
		
		AudioQueueFreeBuffer(playState->queue, outBuffer);
	}

}

-(NGAudioRecord *) init {
	if (self = [super init]) {
		char path[256];
		[self getFilename:path maxLenth:sizeof path];
		fileURL = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8*)path, strlen(path), false);
	}
	
	return self;
}
- (void)setupAudioFormat:(AudioStreamBasicDescription*)format
{
	format->mSampleRate = 16000.0;
	format->mFormatID = kAudioFormatLinearPCM;
	format->mFramesPerPacket = 1;
	format->mChannelsPerFrame = 1;
	format->mBytesPerFrame = 2;
	format->mBytesPerPacket = 2;
	format->mBitsPerChannel = 16;
	format->mReserved = 0;
	format->mFormatFlags = kLinearPCMFormatFlagIsBigEndian     |
	kLinearPCMFormatFlagIsSignedInteger |
	kLinearPCMFormatFlagIsPacked;
}


- (void)startRecording
{
	[self setupAudioFormat:&_recordState.dataFormat];
	
	_recordState.currentPacket = 0;
	_recordState.object = (__bridge void*)self;
	
	OSStatus status;
	status = AudioQueueNewInput(&_recordState.dataFormat,
								AudioInputCallback,
								&_recordState,
								CFRunLoopGetCurrent(),
								kCFRunLoopCommonModes,
								0,
								&_recordState.queue);
	
	if (status == 0)
	{
		// Prime recording buffers with empty data
		for (int i = 0; i < NUM_BUFFERS; i++)
		{
			AudioQueueAllocateBuffer(_recordState.queue, 16000, &_recordState.buffers[i]);
			AudioQueueEnqueueBuffer (_recordState.queue, _recordState.buffers[i], 0, NULL);
		}
		
		status = AudioFileCreateWithURL(fileURL,
										kAudioFileAIFFType,
										&_recordState.dataFormat,
										kAudioFileFlags_EraseFile,
										&_recordState.audioFile);
		if (status == 0)
		{
			_recordState.recording = true;
			status = AudioQueueStart(_recordState.queue, NULL);
			if (status == 0)
			{
				NSLog(@"Recording");
			}
		}
	}
	
	if (status != 0)
	{
		[self stopRecording];
		NSLog(@"Record Failed");
	}
}

- (void)stopRecording
{
	_recordState.recording = false;
	
	AudioQueueFlush(_recordState.queue);
	AudioQueueStop(_recordState.queue, true);
//	for(int i = 0; i < NUM_BUFFERS; i++)
//	{
//		AudioQueueFreeBuffer(_recordState.queue, _recordState.buffers[i]);
//	}
	
	AudioQueueDispose(_recordState.queue, true);
	AudioFileClose(_recordState.audioFile);
	NSLog(@"Idle");
}

- (BOOL)getFilename:(char*)buffer maxLenth:(int)maxBufferLength
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
														 NSUserDomainMask, YES);
	NSString* docDir = [paths objectAtIndex:0];
	
	NSString* file = [docDir stringByAppendingString:@"/recording.aif"];
	NSLog(@"File name and path is %@", file);
	return [file getCString:buffer maxLength:maxBufferLength encoding:NSUTF8StringEncoding];
}


- (void)startPlayback
{
	_playingState.currentPacket = 0;
	_playingState.playing = true;

	[self setupAudioFormat:&_playingState.dataFormat];
	
	OSStatus status;
	status = AudioFileOpenURL(fileURL, kAudioFileReadPermission, kAudioFileWAVEType, &_playingState.audioFile);
	
	
	if (status == 0)
	{
		status = AudioQueueNewOutput(&_playingState.dataFormat,
									 AudioOutputCallback,
									 &_playingState,
									 CFRunLoopGetCurrent(),
									 kCFRunLoopCommonModes,
									 0,
									 &_playingState.queue);
		
		if (status == 0)
		{
			// Allocate and prime playback buffers
			for (int i = 0; i < NUM_BUFFERS && _playingState.playing; i++)
			{
				AudioQueueAllocateBuffer(_playingState.queue, 16000, &_playingState.buffers[i]);
				AudioOutputCallback(&_playingState, _playingState.queue, _playingState.buffers[i]);
			}
			
			status = AudioQueueStart(_playingState.queue, NULL);
			if (status == 0)
			{
				NSLog(@"Playing");
			}
		}
	}
	
	if (status != 0)
	{
		[self stopPlayback];
		NSLog(@"Play failed");
	}
}

- (void)stopPlayback
{
	_playingState.playing = false;
	
	for(int i = 0; i < NUM_BUFFERS; i++)
	{
		AudioQueueFreeBuffer(_playingState.queue, _playingState.buffers[i]);
	}
	
	AudioQueueDispose(_playingState.queue, true);
	AudioFileClose(_playingState.audioFile);
}

- (void)feedSamplesToEngine:(UInt32)audioDataBytesCapacity audioData:(void *)audioData {
	int sampleCount = audioDataBytesCapacity / sizeof(AUDIO_DATA_TYPE_FORMAT);
	AUDIO_DATA_TYPE_FORMAT *samples = (AUDIO_DATA_TYPE_FORMAT*)audioData;
//	NSMutableArray *vudata = [[NSMutableArray alloc] initWithCapacity:sampleCount];
	NSMutableData *vuData = [[NSMutableData alloc] init];
	
	//Do something with the samples
	double power = pow(2,10);
	for ( int i = 0; i < sampleCount; i++) {
		//Do something with samples[i]
		AUDIO_DATA_TYPE_FORMAT sample_le =  (0xff00 & (samples[i] << 8)) | (0x00ff & (samples[i] >> 8)) ; //Endianess issue
		char dataInterim[30];
		sprintf(dataInterim,"%f ", sample_le/power); // normalize it.

		[vuData appendBytes:dataInterim length:30];
	}
	
	[self.recordDelegate didRecordData:vuData];
}

@end
