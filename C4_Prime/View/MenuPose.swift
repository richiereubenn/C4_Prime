//
//  MenuPose.swift
//  C4_Prime
//
//  Created by Richie Reuben Hermanto on 19/06/25.
//

import SwiftUI

struct MenuPose: View {
    
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack {
                    Card()
                    Card()
                    Card()
                    Card()
                }
            }
            .navigationTitle("Select Pose")
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}

#Preview {
    MenuPose()
}
