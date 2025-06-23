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
                    Color.black.ignoresSafeArea()

                        VStack(spacing: 15) {
                            ForEach(PoseModel.poses) { pose in
                                Card(pose: pose)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, -40)
                    
                }
                .navigationTitle("Select Pose")
                .navigationBarTitleDisplayMode(.large)
            }
        }
}

#Preview {
    MenuPose()
}
