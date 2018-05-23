/*****************************************************************************
 * VLCMediaList.m: VLCKit.framework VLCMediaList implementation
 *****************************************************************************
 * Copyright (C) 2018 David Cordero
 * $Id$
 *
 * Authors: David Cordero <david # corderoramirez.com>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

import UIKit

class ViewController: UIViewController {

    var videoView: UIView!

    private var mediaPlayer: VLCMediaPlayer!

    override func viewDidLoad() {
        super.viewDidLoad()

        videoView = UIView(frame: view.bounds)

        mediaPlayer = VLCMediaPlayer()
        mediaPlayer.drawable = view
        mediaPlayer.media = VLCMedia(url: URL(string: "https://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!)

        mediaPlayer.play()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {

        for press in presses {
            switch press.type {
            case .playPause:
                if mediaPlayer.isPlaying {
                    mediaPlayer.pause()
                }
                else {
                    mediaPlayer.play()
                }
            default: ()
            }
        }
    }
}

