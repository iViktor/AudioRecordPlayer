import UIKit
import AVFoundation

class ViewController: UIViewController {
    @IBOutlet var recordButton: UIButton!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var recordingTitleLabel: UILabel!
    @IBOutlet var recordingDurationLabel: UILabel!
    
    private let fileUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("out.m4a")
    
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    private var recordingDurationTimer: Timer?
        
    private lazy var formatter: DateComponentsFormatter = {
        $0.allowedUnits = [.minute, .second]
        $0.unitsStyle = .positional
        $0.zeroFormattingBehavior = .pad
        return $0
    }(DateComponentsFormatter())
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        try? FileManager.default.removeItem(at: fileUrl)
        
        didStop()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print(error)
        }
    }
    
    private func setupRecorder() {
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 24000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: .defaultToSpeaker)
            try AVAudioSession.sharedInstance().setActive(true)
            
            let recorder = try AVAudioRecorder(url: fileUrl, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.delegate = self
            recorder.prepareToRecord()
            self.recorder = recorder
        } catch {
            print("Could not setup recorder")
        }
    }
    
    private func setupPlayer() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: .defaultToSpeaker)
            try AVAudioSession.sharedInstance().setActive(true)
            
            let player = try AVAudioPlayer(contentsOf: fileUrl)
            player.delegate = self
            player.prepareToPlay()
            player.volume = 10.0
            self.player = player
        } catch {
            print("Could not setup player")
        }
    }
    
    // MARK: - Action Methods
    @IBAction func recordButtonTapped(_ sender: Any) {
        
        if let recording = recorder?.isRecording, recording {
            print("Recorder stopping")
            recorder?.stop()
            didStop()
            recorder = nil
        } else {
            print("Recorder starting")
            recorder = nil
            player = nil
            setupRecorder()
            recorder?.prepareToRecord()
            recorder?.record()
            didStart()
        }
    }
    
    @IBAction func playButtonTapped(_ sender: Any) {
        if player?.isPlaying ?? false {
            print("Player stopping")
            player?.pause()
        } else {
            recorder = nil
            player = nil
            setupPlayer()
            print("Player starting/continuing")
            let currentTime = player?.currentTime ?? 0.0
            print("Current time: \(currentTime)")
            if !(player?.play(atTime: currentTime) ?? false) {
                print("player ist kaputt")
            }
        }
    }
    
    // MARK: - DisplayLink
    @objc private func updateMeters() {
        recorder?.updateMeters()
    }
    
    // MARK: - Timer
    @objc private func updateRecordingDuration() {
        if let recorder = recorder, recorder.isRecording {
            let formattedDuration = formatter.string(from: recorder.currentTime) ?? "00:00"
            recordingDurationLabel.text = formattedDuration.count == 5 ? formattedDuration : "0" + formattedDuration
        } else {
            recordingDurationLabel.text = "00:00"
        }
    }
    
    // MARK: - Utility
    private func didStop() {
        displayLink?.invalidate()
        displayLink = nil
        playButton.isEnabled = FileManager.default.fileExists(atPath: fileUrl.path)
        recordingDurationTimer?.invalidate()
        recordingDurationTimer = nil
    }
    
    private func didStart() {
        if displayLink == nil {
            let displayLink = CADisplayLink(target: self, selector: #selector(updateMeters))
            displayLink.add(to: RunLoop.current, forMode: .common)
            self.displayLink = displayLink
        }
        playButton.isEnabled = false
        recordingDurationTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateRecordingDuration), userInfo: nil, repeats: true)
        updateRecordingDuration()
    }
    
    private func powerLevelFromDecibels(decibels: Float) -> Float {
        if decibels < -60.0 || decibels == 0.0 {
            return 0.0
        }
        
        return powf((powf(10.0, 0.05 * decibels) - powf(10.0, 0.05 * -60.0)) * (1.0 / (1.0 - powf(10.0, 0.05 * -60.0))), 1.0 / 2.0)
    }
}

extension ViewController: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        didStop()
    }
}

extension ViewController: AVAudioPlayerDelegate {
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("broken!")
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("why at 00:00?")
    }
}

extension ViewController {
    static var resourceBundle: Bundle? {
        if let bundleUrl = Bundle(for: self).url(forResource: "AudioRecorderResources", withExtension: "bundle"), let resourceBundle = Bundle(url: bundleUrl) {
            return resourceBundle
        } else {
            return nil
        }
    }
}
