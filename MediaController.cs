﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using UnityEngine.UI;
using System.IO;

public class MediaController : MonoBehaviour {

    private AudioSource audio;
    private Text text;

    #if UNITY_IOS
        [DllImport("__Internal")]
        public static extern void exportRandomToItem();

        [DllImport("__Internal")]
        public static extern long getSongId();

        [DllImport("__Internal")]
        public static extern string getSongName();

        [DllImport("__Internal")]
        public static extern bool getDoExport();
    #endif

    // Use this for initialization
	void Start () {

        // プロパティを取得
        audio = GameObject.Find("Audio Source").GetComponent<AudioSource>();
        text = GameObject.Find("Text").GetComponent<Text>();

        // ループ再生するようにする
        audio.loop = true;

        // コルーチンを開始
        StartCoroutine(MusicImport());
	}

    IEnumerator MusicImport() {

        text.text = "楽曲エクスポート中";

        // 曲エクスポートを開始
        exportRandomToItem();

        yield return new WaitForSeconds(0.25f);

        // 曲エクスポート完了まで待つ
        while ( getDoExport() ) yield return new WaitForSeconds(0.25f);

        text.text = "楽曲インポート中";

        // Documentsにある曲を取得
        string path = Application.persistentDataPath + "/" + getSongId() + ".wav";
        WWW www = new WWW("file://" + path);

        // インポートが完了するまで待つ
        while ( !www.isDone ) yield return new WaitForSeconds(0.25f);

        audio.clip = www.GetAudioClip(false, false);

        text.text = "再生します！";

        audio.Play();

        text.text = getSongName();

        // wavファイルを削除
        System.IO.File.Delete(path);
    }
}
