//
//  GameSceneFrameObserver.swift
//  coufistgade
//
//  A frame hook for measurement. SKView's showsFPS draws to the screen and
//  cannot be read back, so verifying that effects do not starve the render loop
//  needs a counter the test can own.
//
//  DEBUG only, and nothing in the app implements it.
//

import Foundation

#if DEBUG
protocol GameSceneFrameObserver: AnyObject {
    func gameSceneDidUpdate()
}
#endif
