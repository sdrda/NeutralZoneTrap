//
//  FocusedValues.swift
//  Neutral Zone Trap
//

import SwiftUI

extension FocusedValues {
    @Entry var selectedTab: Binding<AppTab>?
    @Entry var modeStore: AppModeState?
    @Entry var inspectorPresentedBinding: Binding<Bool>?
    @Entry var fileManager: SessionFileManager?
    @Entry var recorder: (any RecordingControl & SessionSnapshotting)?
}
