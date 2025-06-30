//
//  Card.swift
//  C4_Prime
//
//  Created by Richie Reuben Hermanto on 19/06/25.
//

import SwiftUI

struct Card: View {
    var pose: Pose
    
    var body: some View {
        ZStack {
            Color(red: pose.available ? 24/255 : 16/255,
                  green: pose.available ? 24/255 : 16/255,
                  blue: pose.available ? 22/255 : 18/255)
            
            HStack {
                ZStack(alignment: .bottomLeading) {
                    Image(pose.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 250, height: 300)
                        .cornerRadius(15)
                        .offset(x: -40, y: 30)
                        .opacity(pose.available ? 1.0 : 0.3)
                    
                    VStack(alignment: .trailing) {
                        Spacer()
                        Text(pose.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .padding(.bottom, 10)
                            .offset(x: -20)
                            .opacity(pose.available ? 1.0 : 0.6)
                        
                        if pose.available {
                            NavigationLink(destination:
                                BodyDetection()
                            ) {
                                HStack {
                                    Spacer()
                                    Text("Start")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.yellow)
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.subheadline)
                                        .foregroundColor(.yellow)
                                }
                                .offset(x: -20)
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Locked")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                                
                                Image(systemName: "lock.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .offset(x: -20)
                        }
                        
                        Spacer()
                    }
                    .padding(.leading, 20)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: pose.available ? 24/255 : 16/255,
                                      green: pose.available ? 24/255 : 16/255,
                                      blue: pose.available ? 22/255 : 18/255).opacity(0.0),
                                Color(red: pose.available ? 24/255 : 16/255,
                                      green: pose.available ? 24/255 : 16/255,
                                      blue: pose.available ? 22/255 : 18/255).opacity(0.2),
                                Color(red: pose.available ? 24/255 : 16/255,
                                      green: pose.available ? 24/255 : 16/255,
                                      blue: pose.available ? 22/255 : 18/255).opacity(0.8),
                                Color(red: pose.available ? 24/255 : 16/255,
                                      green: pose.available ? 24/255 : 16/255,
                                      blue: pose.available ? 22/255 : 18/255).opacity(0.7),
                                Color(red: pose.available ? 24/255 : 16/255,
                                      green: pose.available ? 24/255 : 16/255,
                                      blue: pose.available ? 22/255 : 18/255).opacity(1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15)
                }
            }
            if !pose.available {
                ZStack {
                    Color.black.opacity(0.4)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        
                        Text("Coming Soon")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
                .cornerRadius(20)
            }
        }
        .frame(height: 200)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(pose.available ? 0 : 0.5), lineWidth: 1)
        )
        .opacity(pose.available ? 1.0 : 0.8)
    }
}
#Preview {
    Card(pose: Pose(title: "Double Double\nBicep", imageName: "front-double-bicep", available: false))
    Card(pose: Pose(title: "Back Double", imageName: "front-double-bicep", available: true))
    Card(pose: Pose(title: "Side Chest", imageName: "front-double-bicep", available: true))
}
