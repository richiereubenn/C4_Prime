//
//  Card.swift
//  C4_Prime
//
//  Created by Richie Reuben Hermanto on 19/06/25.
//

import SwiftUI

struct Card: View {
    var poseTitle: String = "Front Double\nBicep"

    var body: some View {
        ZStack {
            Color(red: 0.15, green: 0.15, blue: 0.15)

            HStack {
                ZStack(alignment: .bottomLeading) {
                    Image("front-double-bicep")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 250, height: 300)
                        .cornerRadius(15)
                        .offset(x:-40, y:30)
                        
                    
                    VStack(alignment: .trailing) {
                        Spacer()
                        
                        Text(poseTitle)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .padding(.bottom, 10)
                            .offset(x:-20)

                        Button(action: {
                            print("Tombol Start ditekan!")
                        }) {
                            NavigationLink(destination: SelectPhoto()) {
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
                        }
                        
                        Spacer()
                    }
                    .padding(.leading, 20)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.0), // kiri transparan
                                Color(red: 0.15, green: 0.15, blue: 0.15).opacity(1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15)
                    
                }

                
            }

        }
        .frame(height: 180)
        .cornerRadius(20)
    }
}

#Preview {
    Card()
}
