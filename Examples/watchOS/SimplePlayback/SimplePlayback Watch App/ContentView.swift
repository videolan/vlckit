import SwiftUI
import VLCKit

struct PlayerView: View {
    @StateObject private var vlcPlayer = VLCMediaPlayerWrapper()

    var body: some View {
        VStack {
            if let artwork = vlcPlayer.artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 100, maxHeight: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text(vlcPlayer.title)
                .font(.headline)
            Text(vlcPlayer.time)
                .font(.subheadline)
                .padding()

            Button("Play/Pause", action: vlcPlayer.playPause)
        }
        .onAppear {
            vlcPlayer.startPlayback()
        }
    }
}

class VLCMediaPlayerWrapper: NSObject, ObservableObject, VLCMediaPlayerDelegate {
    private var mediaPlayer: VLCMediaPlayer

    @Published var artwork: UIImage?
    @Published var title: String = "No Title"
    @Published var time: String = "00:00"

    override init() {
        self.mediaPlayer = VLCMediaPlayer()
        super.init()
        self.mediaPlayer.delegate = self
    }

    func startPlayback() {
        if let filePath = Bundle.main.path(forResource: "This-Cold", ofType: "m4a") {
            let fileURL = URL(fileURLWithPath: filePath)
            let media = VLCMedia(url: fileURL)
            self.mediaPlayer.media = media
            self.mediaPlayer.play()
        } else {
            print("MP3 file not found")
        }
    }

    func playPause() {
        if self.mediaPlayer.isPlaying {
            self.mediaPlayer.pause()
        } else {
            self.mediaPlayer.play()
        }
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        DispatchQueue.main.async {
            self.time = self.mediaPlayer.time.stringValue
        }
    }

    func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        if let media = self.mediaPlayer.media {
            DispatchQueue.main.async {
                self.title = media.metaData.title ?? "No Title"
                if let artworkImage = media.metaData.artwork {
                    self.artwork = artworkImage
                } else {
                    self.artwork = UIImage(named: "Image")
                }
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        PlayerView()
    }
}
