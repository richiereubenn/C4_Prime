//
//  MenuPose.swift
//  C4_Prime
//
//  Created by Richie Reuben Hermanto on 19/06/25.
//

import SwiftUI

struct MenuPose: View {
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
//
//                ScrollView {
                    VStack(spacing: 15) {
                        Card()
                        Card()
                        Card()
                    }
                    .padding()
//                }
            }
            .navigationTitle("Select Pose")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    MenuPose()
}
