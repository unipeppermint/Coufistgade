//
//  MotionPreference.swift
//  coufistgade
//
//  The single answer to "should this animate?".
//
//  Reduce Motion has two sources: iOS's own accessibility setting and the app's
//  own switch (UI_DESIGN §15). They must be OR-merged — a player who has asked
//  for less motion in either place has asked for it, and honouring only one
//  would make the app's switch a lie on a device that already had the system
//  setting on.
//
//  Every animating view takes its preference as a closure, defaulted to this.
//  Reading UIAccessibility directly anywhere else would reintroduce the split.
//

import UIKit

enum MotionPreference {

    /// Overridden by the app's stored setting; nil means read from storage.
    /// Kept injectable so tests need not touch UserDefaults.
    static var storedPreference: () -> Bool = { PersistenceManager().reduceMotionEnabled }

    /// True when motion should be reduced, from either source.
    static var isReduced: Bool {
        UIAccessibility.isReduceMotionEnabled || storedPreference()
    }
}
