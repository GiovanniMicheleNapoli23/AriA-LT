//
//  AriaSwitchToggleStyle.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Gli interruttori dell'app sono verdi, come quelli di sistema: col colore dell'app (bianco lilla al buio)
//  un interruttore acceso non si distingueva da uno spento. Si imposta una volta sola alla radice; la tinta
//  sta sull'interruttore stesso, quindi vince su un `.tint` messo fuori dal Toggle. Chi vuole un altro stile
//  (es. `.toggleStyle(.button)`) lo dichiara sul suo Toggle.
//

import SwiftUI

struct AriaSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration)
            .toggleStyle(.switch)
            .tint(.green)
    }
}

extension ToggleStyle where Self == AriaSwitchToggleStyle {
    static var ariaSwitch: AriaSwitchToggleStyle { AriaSwitchToggleStyle() }
}
