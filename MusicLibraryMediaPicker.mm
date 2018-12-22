# import <Foundation/Foundation.h>
# import <MediaPlayer/MediaPlayer.h>
# import <AVFoundation/AVAudioFile.h>
# import <AVFoundation/AVAudioEngine.h>
# import <AVFoundation/AVFoundation.h>
# import <AVFoundation/AVAssetReader.h>
# import <AVFoundation/AVAssetWriter.h>

extern "C" {
    
    // プロパティ
    BOOL do_export;
    long song_id;
    NSString* song_name;
    
    // 関数のプロトタイプ宣言
    void exportRandomToItem();
    long getSongId();
    char* getSongName();
    BOOL getDoExport();
    
    
    /***************************************************
     * MPMediaItemをwav形式でDocumentフォルダに出力する関数
     * @param item 出力したい曲のMPMediaItem
     * @return 正しく出力できたらYESを返す
     ***************************************************/
    BOOL exportItem (MPMediaItem *item) {
        // エクスポートフラグを立てる
        do_export = YES;
        // エラー表示用の変数
        NSError *error = nil;
        // WAVEファイルのフォーマット
        NSDictionary *audioSetting = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithFloat:44100.0],AVSampleRateKey,
                                      [NSNumber numberWithInt:2],AVNumberOfChannelsKey,
                                      [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,
                                      [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                      [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
                                      [NSNumber numberWithBool:0], AVLinearPCMIsBigEndianKey,
                                      [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
                                      [NSData data], AVChannelLayoutKey, nil];
        // 指定ファイルまでのパス
        NSURL *url = [item valueForProperty:MPMediaItemPropertyAssetURL];
        // ↑の*urlからメディアデータへのアクセス用リンクを作成
        AVURLAsset *URLAsset = [AVURLAsset URLAssetWithURL:url options:nil];
        if (!URLAsset) {
            do_export = NO;
            return NO;
        }
        // ↑で作ったリンクをもとに指定されたアセットからメディアデータを読み取るアセットリーダーを返します。
        AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:URLAsset error:&error];
        if (error) {
            do_export = NO;
            return NO;
        }
        // メディアタイプのコンポジショントラックの配列を返す。
        NSArray *tracks = [URLAsset tracksWithMediaType:AVMediaTypeAudio];
        if (![tracks count]) {
            do_export = NO;
            return NO;
        }
        // アセットトラックからミックスされたオーディオデータを読み取る。
        AVAssetReaderAudioMixOutput *audioMixOutput = [AVAssetReaderAudioMixOutput
                                                       assetReaderAudioMixOutputWithAudioTracks:tracks
                                                       audioSettings:audioSetting];
        if (![assetReader canAddOutput:audioMixOutput]) {
            do_export = NO;
            return NO;
        }
        // 実際にミュージックデータを読み込む
        [assetReader addOutput:audioMixOutput];
        if (![assetReader startReading]) {
            do_export = NO;
            return NO;
        }
        // パスを作成
        NSArray *docDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docDir = [docDirs objectAtIndex:0];
        NSString *outPath = [[docDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", [item valueForProperty:MPMediaItemPropertyPersistentID]]]
                             stringByAppendingPathExtension:@"wav"];
        // 書き込みファイルまでのパスまでのリンクを作成
        NSURL *outURL = [NSURL fileURLWithPath:outPath];
        // ↑で作ったリンクをもとに指定されたUTIで指定された形式で、指定されたURLで識別されるファイルに書き込むためのアセットライターを返します。
        AVAssetWriter *assetWriter = [AVAssetWriter assetWriterWithURL:outURL
                                                              fileType:AVFileTypeWAVE
                                                                 error:&error];
        if (error) {
            do_export = NO;
            return NO;
        }
        //ファイルが存在している場合は削除する
        NSFileManager *manager = [NSFileManager defaultManager];
        if([manager fileExistsAtPath:outPath]) [manager removeItemAtPath:outPath error:&error];
        if (error) {
            do_export = NO;
            return NO;
        }
        // データを書き込みする際に利用する
        AVAssetWriterInput *assetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                                                  outputSettings:audioSetting];
        // リアルタイムで入力するか
        assetWriterInput.expectsMediaDataInRealTime = NO;
        if (![assetWriter canAddInput:assetWriterInput]) {
            do_export = NO;
            return NO;
        }
        // 書き込む情報を追加する
        [assetWriter addInput:assetWriterInput];
        if (![assetWriter startWriting]) {
            do_export = NO;
            return NO;
        }
        // コピー処理
        // ARCをオフにしているので自分で参照カウントを+1する
        [assetReader retain];
        [assetWriter retain];
        // 設定した情報を実際に書き込みを開始する
        [assetWriter startSessionAtSourceTime:kCMTimeZero];
        // 非同期処理
        dispatch_queue_t queue = dispatch_queue_create("assetWriterQueue", NULL);
        [assetWriterInput requestMediaDataWhenReadyOnQueue:queue usingBlock:^{
            while ( 1 ) {
                // ファイルの書き込みが出来るか
                if ([assetWriterInput isReadyForMoreMediaData]) {
                    // サンプルバッファーを出力用にコピーする
                    CMSampleBufferRef sampleBuffer = [audioMixOutput copyNextSampleBuffer];
                    if (sampleBuffer) {
                        // サンプルバッファーを追加する
                        [assetWriterInput appendSampleBuffer:sampleBuffer];
                        // オブジェクトを解放する
                        CFRelease(sampleBuffer);
                    } else {
                        // バッファーを追加出来ないようにする
                        [assetWriterInput markAsFinished];
                        break;
                    }
                }
            }
            // ディスパッチオブジェクトの参照（保持）カウントを減少させます。
            [assetWriter finishWriting];
            // ARCをオフにしているので自分で参照カウントを-1する
            [assetReader release];
            [assetWriter release];
            do_export = NO;
        }];
        dispatch_release(queue);
        return YES;
    }
    
    
    /**************************************
     * ランダムで曲をエクスポートする
     * @return エクスポートが完了したらYESを返す
     **************************************/
    void exportRandomToItem() {
        
        /// 曲情報を取得する処理
        MPMediaQuery* songQuery = [MPMediaQuery songsQuery];
        
        // 使える曲の配列
        NSMutableArray<MPMediaItem*>* array = [[NSMutableArray<MPMediaItem*> alloc] init];
        
        // ここでiCloudにしかない曲を弾く
        [songQuery addFilterPredicate:[MPMediaPropertyPredicate predicateWithValue:[NSNumber numberWithBool:NO] forProperty:MPMediaItemPropertyIsCloudItem]];
        NSArray *songlists = songQuery.collections;
        
        // 使える曲リストを作成
        for ( int i = 0; i < [songlists count]; i++ ) {
            MPMediaItemCollection* songlist = [songlists objectAtIndex:i];
            MPMediaItem* item = [songlist representativeItem];
            if ( ![item hasProtectedAsset] ) [array addObject:item];
        }
        
        // 曲をエクスポート
        NSUInteger index = arc4random_uniform([array count]);
        MPMediaItem* item = [array objectAtIndex:index];
        song_id = [[item valueForProperty:MPMediaItemPropertyPersistentID] longValue];
        song_name = [item valueForProperty:MPMediaItemPropertyTitle];
        exportItem(item);
    }
    
    
    /************************************
     * セットされている曲のIDを取得する関数
     * @return セットされている曲のIDを返す
     ************************************/
    long getSongId() {
        return song_id;
    }
    
    
    /****************************************
     * セットされている曲のタイトルを取得する関数
     * @return セットされている曲のタイトルを返す
     ****************************************/
    char* getSongName() {
        return strdup([song_name UTF8String]);
    }
    
    
    /*******************************
     * コピー中かどうか判定する関数
     * @return コピー中ならYESを返す
     *******************************/
    BOOL getDoExport() {
        return do_export;
    }
}
